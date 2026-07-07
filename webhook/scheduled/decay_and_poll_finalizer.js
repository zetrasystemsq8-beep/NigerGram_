const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Trending decay: -0.5/hour, floor at 0, only touches posts with score > 0
async function decayTrendingScores() {
  const snapshot = await db
    .collection('gist_posts')
    .where('trendingScore', '>', 0)
    .get();

  if (snapshot.empty) return { decayed: 0 };

  const batch = db.batch();
  let count = 0;

  snapshot.docs.forEach((doc) => {
    const current = doc.data().trendingScore || 0;
    const next = Math.max(0, current - 0.5);
    batch.update(doc.ref, { trendingScore: next });
    count++;
  });

  await batch.commit();
  return { decayed: count };
}

// Dynamic trending cutoff: top 5% of all posts by trendingScore, with a
// floor of 10 so low-activity periods can't let near-zero posts qualify.
// Stored in config/trending so the app can read it without recalculating.
async function calculateTrendingCutoff() {
  const snapshot = await db.collection('gist_posts').get();

  if (snapshot.empty) {
    await db.collection('config').doc('trending').set({
      minScore: 10,
      totalPosts: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { minScore: 10, totalPosts: 0 };
  }

  const scores = snapshot.docs
    .map((doc) => doc.data().trendingScore)
    .filter((s) => typeof s === 'number')
    .sort((a, b) => b - a);

  if (scores.length === 0) {
    await db.collection('config').doc('trending').set({
      minScore: 10,
      totalPosts: snapshot.size,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { minScore: 10, totalPosts: snapshot.size };
  }

  const cutoffIndex = Math.max(0, Math.ceil(scores.length * 0.05) - 1);
  let minScore = scores[cutoffIndex];

  if (minScore < 10) {
    minScore = 10;
  }

  await db.collection('config').doc('trending').set({
    minScore,
    totalPosts: scores.length,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { minScore, totalPosts: scores.length };
}

// Poll expiry: mark expired active polls inactive, then promote ONLY the
// single highest-voted poll among those just expired to a poll_result post
// (which starts with a trendingScore above the Trending threshold so it
// surfaces immediately, then decays naturally like any other post).
async function finalizeExpiredPolls() {
  const now = admin.firestore.Timestamp.now();

  const snapshot = await db
    .collection('gist_posts')
    .where('type', '==', 'poll')
    .where('isPollActive', '==', true)
    .where('expiresAt', '<=', now)
    .get();

  if (snapshot.empty) return { expired: 0, winnerCreated: false };

  const batch = db.batch();
  let winnerDoc = null;
  let winnerTotalVotes = -1;

  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { isPollActive: false });

    const data = doc.data();
    const pollVotes = data.pollVotes || {};
    const totalVotes = Object.values(pollVotes).reduce(
      (sum, v) => sum + (typeof v === 'number' ? v : 0),
      0
    );

    if (totalVotes > winnerTotalVotes) {
      winnerTotalVotes = totalVotes;
      winnerDoc = { id: doc.id, data, totalVotes };
    }
  });

  await batch.commit();

  let winnerCreated = false;

  if (winnerDoc && winnerDoc.totalVotes > 0) {
    const { data, totalVotes } = winnerDoc;
    const pollOptions = data.pollOptions || [];
    const pollVotes = data.pollVotes || {};

    let winningIndex = 0;
    let winningVotes = -1;
    Object.entries(pollVotes).forEach(([indexStr, votes]) => {
      if (votes > winningVotes) {
        winningVotes = votes;
        winningIndex = parseInt(indexStr, 10);
      }
    });

    const winningOption = pollOptions[winningIndex] || 'Unknown option';
    const winningPercentage = totalVotes > 0
      ? Math.round((winningVotes / totalVotes) * 100)
      : 0;

    const resultRef = db.collection('gist_posts').doc();
    await resultRef.set({
      userId: data.userId || '',
      displayName: data.displayName || 'Anonymous',
      username: data.username || 'user',
      profilePic: data.profilePic || '',
      type: 'poll_result',
      content: `📊 Poll result: "${data.content}" — "${winningOption}" won with ${winningPercentage}% of votes`,
      imageUrl: null,
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      pollVoters: {},
      reactions: {
        "😂": 0,
        "😱": 0,
        "👀": 0,
        "🥴": 0,
        "🇳🇬": 0,
      },
      commentCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: null,
      isAnonymous: data.isAnonymous || false,
      totalReactions: 0,
      trendingScore: 15.0,
      isPollActive: false,
    });

    winnerCreated = true;
  }

  return { expired: snapshot.size, winnerCreated };
}

// Combined cron handler — mount this at your existing cron endpoint
async function gistHubCronHandler(req, res) {
  try {
    const decayResult = await decayTrendingScores();
    const cutoffResult = await calculateTrendingCutoff();
    const pollResult = await finalizeExpiredPolls();

    res.status(200).json({
      success: true,
      decay: decayResult,
      trendingCutoff: cutoffResult,
      polls: pollResult,
    });
  } catch (error) {
    console.error('❌ Gist Hub cron error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

module.exports = {
  decayTrendingScores,
  calculateTrendingCutoff,
  finalizeExpiredPolls,
  gistHubCronHandler,
};
