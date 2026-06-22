import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/init/router/app_router.dart';
import 'package:nigergram/features/video_feed/data/repository_impl/video_feed_repository_impl.dart';
import 'package:nigergram/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:nigergram/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:nigergram/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:nigergram/core/services/monnify_service.dart';
import 'package:nigergram/features/wallet/data/repository_impl/wallet_repository_impl.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';

final getIt = GetIt.instance;

void injectionSetup() {
  // Router
  getIt
    ..registerSingleton<AppRouter>(AppRouter())
    // Firebase
    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)
    // Services
    ..registerLazySingleton<MonnifyService>(() => MonnifyService())
    // Repositories
    ..registerLazySingleton<VideoFeedRepository>(
      () => VideoFeedRepositoryImpl(firestore: getIt<FirebaseFirestore>()),
    )
    ..registerLazySingleton<WalletRepositoryImpl>(
      () => WalletRepositoryImpl(firestore: getIt<FirebaseFirestore>()),
    )
    // UseCases
    ..registerLazySingleton<FetchVideosUseCase>(
      () => FetchVideosUseCase(repository: getIt<VideoFeedRepository>()),
    )
    ..registerLazySingleton<FetchMoreVideosUseCase>(
      () => FetchMoreVideosUseCase(repository: getIt<VideoFeedRepository>()),
    )
    // Cubits
    ..registerFactory<VideoFeedCubit>(
      () => VideoFeedCubit(
        fetchVideosUseCase: getIt<FetchVideosUseCase>(),
        fetchMoreVideosUseCase: getIt<FetchMoreVideosUseCase>(),
      ),
    )
    ..registerFactory<WalletCubit>(
      () => WalletCubit(repository: getIt<WalletRepositoryImpl>()),
    );
}
