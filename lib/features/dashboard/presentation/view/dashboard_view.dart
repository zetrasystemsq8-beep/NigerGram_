1| import 'dart:ui';
2| import 'package:flutter/material.dart';
3| import 'package:go_router/go_router.dart';
4| import 'package:nigergram/core/config/localization/app_localizations.dart';
5| import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
6| import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
7| import 'package:nigergram/features/video_feed/presentation/view/video_feed_view.dart';
8| import 'package:nigergram/features/profile/presentation/view/profile_view.dart';
9| import 'package:nigergram/features/gist_hub/presentation/view/gist_hub_view.dart';
10| 
11| class DashboardView extends StatefulWidget {
12|   const DashboardView({super.key});
13| 
14|   @override
15|   State<DashboardView> createState() => _DashboardViewState();
16| }
17| 
18| class _DashboardViewState extends State<DashboardView> {
19|   int _currentIndex = 0;
20| 
21|   late final List<Widget> _navigationPages = [
22|     const VideoFeedView(),
23|     const GistHubView(),
24|     const SizedBox(),
25|     const _InboxPlaceholder(),
26|     const ProfileView(),
27|   ];
28| 
29|   void _handleTabSelection(int index) {
30|     if (index == 2) {
31|       context.push(RouterEnum.uploadView.routeName);
32|       return;
33|     }
34|     setState(() => _currentIndex = index);
35|   }
36| 
37|   @override
38|   Widget build(BuildContext context) {
39|     final localizations = AppLocalizations.of(context);
40| 
41|     return Scaffold(
42|       backgroundColor: Colors.black,
43|       body: Stack(
44|         children: [
45|           Positioned.fill(
46|             child: IndexedStack(
47|               index: _currentIndex,
48|               children: _navigationPages,
49|             ),
50|           ),
51|           Positioned(
52|             left: 0,
53|             right: 0,
54|             bottom: 0,
55|             child: ClipRect(
56|               child: BackdropFilter(
57|                 filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
58|                 child: Container(
59|                   height: context.h(84),
60|                   decoration: BoxDecoration(
61|                     color: Colors.black.withAlpha(150),
62|                     border: Border(
63|                       top: BorderSide(
64|                         color: Colors.white.withAlpha(20),
65|                         width: 0.5,
66|                       ),
67|                     ),
68|                   ),
69|                   padding: EdgeInsets.symmetric(horizontal: context.w(8)),
70|                   child: SafeArea(
71|                     top: false,
72|                     child: Row(
73|                       mainAxisAlignment: MainAxisAlignment.spaceAround,
74|                       children: [
75|                         _buildNavigationTabItem(
76|                           index: 0,
77|                           icon: Icons.home_filled,
78|                           label: localizations?.dashboard ?? 'Home',
79|                         ),
80|                         _buildNavigationTabItem(
81|                           index: 1,
82|                           icon: Icons.grid_view_rounded,
83|                           label: 'Gist Hub',
84|                         ),
85|                         GestureDetector(
86|                           onTap: () => _handleTabSelection(2),
87|                           child: SizedBox(
88|                             width: context.w(48),
89|                             height: context.h(30),
90|                             child: Stack(
91|                               children: [
92|                                 Positioned(
93|                                   left: 0,
94|                                   top: 0,
95|                                   bottom: 0,
96|                                   child: Container(
97|                                     width: context.w(38),
98|                                     decoration: BoxDecoration(
99|                                       color: const Color(0xFFFE2C55),
100|                                       borderRadius: BorderRadius.circular(
101|                                           context.w(8)),
102|                                     ),
103|                                   ),
104|                                 ),
105|                                 Positioned(
106|                                   right: 0,
107|                                   top: 0,
108|                                   bottom: 0,
109|                                   child: Container(
110|                                     width: context.w(38),
111|                                     decoration: BoxDecoration(
112|                                       color: const Color(0xFF23F6E4),
113|                                       borderRadius: BorderRadius.circular(
114|                                           context.w(8)),
115|                                     ),
116|                                   ),
117|                                 ),
118|                                 Center(
119|                                   child: Container(
120|                                     width: context.w(40),
121|                                     height: context.h(30),
122|                                     decoration: BoxDecoration(
123|                                       color: Colors.white,
124|                                       borderRadius: BorderRadius.circular(
125|                                           context.w(8)),
126|                                     ),
127|                                     child: const Icon(
128|                                       Icons.add,
129|                                       color: Colors.black,
130|                                       size: 22,
131|                                     ),
132|                                   ),
133|                                 ),
134|                               ],
135|                             ),
136|                           ),
137|                         ),
138|                         _buildNavigationTabItem(
139|                           index: 3,
140|                           icon: Icons.chat_bubble_outline_rounded,
141|                           label: 'Inbox',
142|                         ),
143|                         _buildNavigationTabItem(
144|                           index: 4,
145|                           icon: Icons.person_outline_rounded,
146|                           label: 'Me',
147|                         ),
148|                       ],
149|                     ),
150|                   ),
151|                 ),
152|               ),
153|             ),
154|           ),
155|         ],
156|       ),
157|     );
158|   }
159| 
160|   Widget _buildNavigationTabItem({
161|     required int index,
162|     required IconData icon,
163|     required String label,
164|     int badgeNotificationCount = 0,
165|   }) {
166|     final bool isActive = _currentIndex == index;
167| 
168|     return GestureDetector(
169|       onTap: () => _handleTabSelection(index),
170|       behavior: HitTestBehavior.opaque,
171|       child: SizedBox(
172|         width: context.w(60),
173|         child: Stack(
174|           alignment: Alignment.center,
175|           clipBehavior: Clip.none,
176|           children: [
177|             Column(
178|               mainAxisAlignment: MainAxisAlignment.center,
179|               mainAxisSize: MainAxisSize.min,
180|               spacing: context.h(4),
181|               children: [
182|                 Icon(
183|                   icon,
184|                   color: isActive
185|                       ? Colors.white
186|                       : Colors.white.withAlpha(150),
187|                   size: context.sq(26),
188|                 ),
189|                 Text(
190|                   label,
191|                   maxLines: 1,
192|                   style: TextStyle(
193|                     color: isActive
194|                         ? Colors.white
195|                         : Colors.white.withAlpha(150),
196|                     fontSize: context.fontSize(10),
197|                     fontWeight: isActive
198|                         ? FontWeight.bold
199|                         : FontWeight.w500,
200|                   ),
201|                 ),
202|               ],
203|             ),
204|             if (badgeNotificationCount > 0)
205|               Positioned(
206|                 top: context.h(-4),
207|                 right: context.w(2),
208|                 child: Container(
209|                   padding: EdgeInsets.symmetric(
210|                     horizontal: context.w(5),
211|                     vertical: context.h(1),
212|                   ),
213|                   decoration: BoxDecoration(
214|                     color: const Color(0xFFFE2C55),
215|                     borderRadius:
216|                         BorderRadius.circular(context.w(10)),
217|                   ),
218|                   constraints: BoxConstraints(minWidth: context.w(16)),
219|                   child: Text(
220|                     badgeNotificationCount.toString(),
221|                     style: TextStyle(
222|                       color: Colors.white,
223|                       fontSize: context.fontSize(9),
224|                       fontWeight: FontWeight.bold,
225|                     ),
226|                     textAlign: TextAlign.center,
227|                   ),
228|                 ),
229|               ),
230|           ],
231|         ),
232|       ),
233|     );
234|   }
235| }
236| 
237| class _InboxPlaceholder extends StatelessWidget {
238|   const _InboxPlaceholder();
239| 
240|   @override
241|   Widget build(BuildContext context) {
242|     return const Scaffold(
243|       backgroundColor: Colors.black,
244|       body: Center(
245|         child: Text(
246|           'Inbox',
247|           style: TextStyle(color: Colors.white, fontSize: 18),
248|         ),
249|       ),
250|     );
251|   }
252| }
