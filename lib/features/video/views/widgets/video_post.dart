import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hashtagable/hashtagable.dart';
import 'package:shake/shake.dart';
import 'package:share_plus/share_plus.dart';
import 'package:surfify/constants/gaps.dart';
import 'package:surfify/constants/sizes.dart';
import 'package:surfify/features/users/view_models/user_view_model.dart';
import 'package:surfify/features/video/view_models/compass_view_model.dart';
import 'package:surfify/features/video/view_models/lucky_view_model.dart';
import 'package:surfify/features/video/views/widgets/search_bar.dart';
import 'package:surfify/features/video/views/widgets/video_button.dart';
import 'package:surfify/features/video/views/widgets/video_comments.dart';
import 'package:surfify/features/video/views/widgets/video_compass.dart';
import 'package:surfify/features/video/views/widgets/video_location.dart';
import 'package:surfify/features/video/views/widgets/video_radar.dart';

import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../authentication/repos/authentication_repo.dart';
import '../../../users/user_profile_screen.dart';
import '../../models/video_model.dart';
import '../../view_models/search_condition_view_model.dart';
import '../../view_models/video_post_view_model.dart';
import '../opinion_screen.dart';
import '../search_screen.dart';
import 'like.dart';

class VideoPost extends ConsumerStatefulWidget {
  final Function onVideoFinished;
  final VideoModel videoData;
  final int index;
  final bool radar;
  final bool now;
  final bool luckyMode;
  final double currentLatitude;
  final double currentLongitude;

  const VideoPost({
    super.key,
    required this.videoData,
    required this.onVideoFinished,
    required this.index,
    required this.radar,
    required this.now,
    required this.luckyMode,
    required this.currentLatitude,
    required this.currentLongitude,
  });

  @override
  VideoPostState createState() => VideoPostState();
}

class VideoPostState extends ConsumerState<VideoPost>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;

  final Duration _animationDuration = const Duration(milliseconds: 200);

  late final AnimationController _animationController;

  bool showDetail = false;

  bool _isPaused = false;

  var like = 0;

  void _onVideoChange() {
    print('change');
    if (_videoPlayerController.value.isInitialized) {
      if (_videoPlayerController.value.duration ==
          _videoPlayerController.value.position) {
        widget.onVideoFinished();
      }
    }
  }

  void _initVideoPlayer() async {
    _videoPlayerController =
        VideoPlayerController.network(widget.videoData.fileUrl);

    await _videoPlayerController.initialize();
    if (!widget.luckyMode) await _videoPlayerController.setLooping(true);
    // await _videoPlayerController
    //     .seekTo(const Duration(milliseconds: 1)); // minor bug..
    _videoPlayerController.addListener(_onVideoChange);
    if (!widget.now) _videoPlayerController.play();
    setState(() {});
  }

  void _updateVideoPlayer() async {
    _videoPlayerController.pause();
    _videoPlayerController =
        VideoPlayerController.network(widget.videoData.fileUrl);

    await _videoPlayerController.initialize();
    // if (!widget.luckyMode) await _videoPlayerController.setLooping(true);
    // await _videoPlayerController
    //     .seekTo(const Duration(milliseconds: 1)); // minor bug..
    // _videoPlayerController.addListener(_onVideoChange);
    if (!widget.now) _videoPlayerController.play();
  }

  @override
  void initState() {
    // print("init");
    super.initState();
    _initVideoPlayer();
    ShakeDetector detector = ShakeDetector.autoStart(
      onPhoneShake: () {
        setState(() {
          ref.watch(luckyProvider.notifier).setLucky();
          ref.read(compassProvider.notifier).setUncompass();
        });
        // Do stuff on phone shake
      },
      minimumShakeCount: 2,
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
      shakeThresholdGravity: 2.7,
    );

    _animationController = AnimationController(
      vsync: this,
      lowerBound: 1.0,
      upperBound: 1.5,
      value: 1.5,
      duration: _animationDuration,
    );
  }

  @override
  void didUpdateWidget(covariant VideoPost oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 새로운 속성에 기반한 작업 수행
    if (!widget.radar && !oldWidget.radar) {
      print("update");
      _updateVideoPlayer();
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    print('dispose됨');

    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    print("visibility change");
    if (!mounted) return;
    if (info.visibleFraction == 1 &&
        !_isPaused &&
        !_videoPlayerController.value.isPlaying) {
      _videoPlayerController.play();
    }
    if (_videoPlayerController.value.isPlaying && info.visibleFraction == 0) {
      _videoPlayerController.pause();
    }
  }

  void _onEditTap() {
    // print(widget.videoData.geoHash);
    // print(widget.videoData.id);
    // print(widget.videoData.description);
    Navigator.of(context).pop();
  }

  void _onTogglePause() {
    if (!mounted) return;
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
      _animationController.reverse();
      _isPaused = true;
    } else {
      _videoPlayerController.play();
      _animationController.forward();
      _isPaused = false;
    }
    setState(() {});
  }

  void _onDeleteVideo() {
    print(widget.videoData.id);
    ref
        .watch(videoPostProvider(widget.videoData.id).notifier)
        .deleteVideo(widget.videoData);
    Navigator.of(context).pop();
  }

  void _onLikeTap() {
    ref
        .watch(videoPostProvider(widget.videoData.id).notifier)
        .toggleLikeVideo();
  }

  void _onCommentsTap(BuildContext context) async {
    if (_videoPlayerController.value.isPlaying) {
      _onTogglePause();
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoComments(
        videoId: widget.videoData.id,
        creatorId: widget.videoData.creatorUid,
      ),
    );
    _onTogglePause();
  }

  @override
  Widget build(BuildContext context) {
    var radarMode = widget.radar;
    final size = MediaQuery.of(context).size;
    final videoId = widget.videoData.id;

    return VisibilityDetector(
      key: Key("${widget.index}"),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
        children: [
          Positioned.fill(
              child: Image.network(
            widget.videoData.thumbnailUrl,
            fit: BoxFit.cover,
          )),
          Positioned.fill(
            child: _videoPlayerController.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                        height: _videoPlayerController.value.size.height,
                        width: _videoPlayerController.value.size.width,
                        child: VideoPlayer(_videoPlayerController)))
                : Container(),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: _onTogglePause,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _animationController.value,
                      child: child,
                    );
                  },
                  child: AnimatedOpacity(
                    opacity: _isPaused ? 1 : 0,
                    duration: _animationDuration,
                    child: const FaIcon(
                      FontAwesomeIcons.play,
                      color: Colors.white,
                      size: Sizes.size52,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () async {
                    await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => UserProfileScreen(
                            uid: widget.videoData.creatorUid));
                  },
                  child: Column(
                    children: [
                      FutureBuilder(builder:
                          (BuildContext context, AsyncSnapshot snapshot) {
                        if (ref
                                .read(
                                    usersProvider(widget.videoData.creatorUid))
                                .value ==
                            null) {
                          return const Text(
                            '...',
                            style: TextStyle(
                              fontSize: Sizes.size20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        } else {
                          if (ref
                              .read(usersProvider(widget.videoData.creatorUid))
                              .value!
                              .hasAvatar) {
                            return CircleAvatar(
                              radius: 28,
                              foregroundImage: NetworkImage(
                                  "https://firebasestorage.googleapis.com/v0/b/surfify.appspot.com/o/avatars%2F${widget.videoData.creatorUid}?alt=media"),
                              child: null,
                            );
                          } else {
                            return CircleAvatar(
                                radius: 28,
                                foregroundImage: null,
                                child: Text(
                                  ref
                                      .read(usersProvider(
                                          widget.videoData.creatorUid))
                                      .value!
                                      .name,
                                ));
                          }
                        }
                      }),
                      Gaps.v12,
                      FutureBuilder(builder:
                          (BuildContext context, AsyncSnapshot snapshot) {
                        if (ref
                                .read(
                                    usersProvider(widget.videoData.creatorUid))
                                .value ==
                            null) {
                          return const Text(
                            '...',
                            style: TextStyle(
                              fontSize: Sizes.size20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        } else {
                          return Text(
                            ref
                                .read(
                                    usersProvider(widget.videoData.creatorUid))
                                .value!
                                .name,
                            style: const TextStyle(
                              fontSize: Sizes.size20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                      })
                    ],
                  ),
                ),
                Gaps.v10,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    showDetail
                        ? SizedBox(
                            width: size.width * 0.75,
                            child: HashTagText(
                              text: widget.videoData.description,
                              basicStyle: const TextStyle(
                                fontSize: Sizes.size16,
                                color: Colors.white,
                              ),
                              decoratedStyle: TextStyle(
                                fontSize: Sizes.size16,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              onTap: (string) async {
                                if (!widget.now) {
                                  ref
                                      .watch(luckyProvider.notifier)
                                      .setUnLucky();
                                  await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          const SearchScreen());
                                }
                              },
                            ),
                          )
                        : HashTagText(
                            text: widget.videoData.description.length >= 40
                                ? '${widget.videoData.description.substring(0, 25)}...'
                                : widget.videoData.description,
                            basicStyle: const TextStyle(
                              fontSize: Sizes.size16,
                              color: Colors.white,
                            ),
                            decoratedStyle: TextStyle(
                              fontSize: Sizes.size16,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            onTap: (string) async {
                              if (!widget.now) {
                                ref.watch(luckyProvider.notifier).setUnLucky();
                                await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => const SearchScreen());
                              }
                            },
                          ),
                    Gaps.h24,
                    widget.videoData.description.length >= 40
                        ? GestureDetector(
                            onTap: () => {
                              setState(() {
                                showDetail = !showDetail;
                              })
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: showDetail
                                    ? const Text('줄이기',
                                        style: TextStyle(
                                          fontSize: Sizes.size12,
                                          color: Colors.white,
                                        ))
                                    : const Text('더보기',
                                        style: TextStyle(
                                          fontSize: Sizes.size12,
                                          color: Colors.white,
                                        )),
                              ),
                            ),
                          )
                        : const Text(''),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 185,
            right: 8.5,
            child: Container(
              width: 48,
              height: 260,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(50), bottom: Radius.circular(50)),
                color: Color.fromRGBO(0, 0, 0, 0.22),
              ),
            ),
          ),
          Positioned(
            bottom: 180,
            right: 9,
            child: Column(
              children: [
                ref.read(videoPostProvider(videoId)).when(
                      loading: () => GestureDetector(
                        onTap: null,
                        child: VideoButton(
                          icon: Icons.favorite,
                          text: "${widget.videoData.likes}",
                          color: Colors.white,
                        ),
                      ),
                      error: (error, stackTrace) => const SizedBox(),
                      data: (data) {
                        return Like(
                          number: widget.videoData.likes,
                          originallyLiked: data,
                          videoId: widget.videoData.id,
                          creatorId: widget.videoData.creatorUid,
                        );
                      },
                    ),
                Gaps.v20,
                GestureDetector(
                  onTap: () => _onCommentsTap(context),
                  child: VideoButton(
                    icon: FontAwesomeIcons.solidCommentDots,
                    text: '${widget.videoData.comments}',
                    color: Colors.white,
                  ),
                ),
                Gaps.v20,
                ElevatedButton(
                  onPressed: () async {
                    await Share.share("https://surfi.ai/");
                  },
                  style: ElevatedButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.all(0), // 버튼의 내부 여백을 조정합니다
                    minimumSize: const Size(1, 1), // 버튼의 최소 크기를 지정합니다
                  ),
                  child: const VideoButton(
                    icon: FontAwesomeIcons.shareNodes,
                    text: "",
                    color: Colors.white,
                  ),
                ),
                Gaps.v20,
                GestureDetector(
                  onTap: () async {
                    await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            OptionScreen(videoId: widget.videoData.id));
                  },
                  child: const VideoButton(
                    icon: FontAwesomeIcons.ellipsisVertical,
                    text: "",
                    color: Colors.white,
                  ),
                )
              ],
            ),
          ),
          ref.read(authRepo).user!.uid == widget.videoData.creatorUid
              ? Positioned(
                  bottom: 45,
                  right: 20,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text("기록을 삭제할까요?"),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: _onEditTap,
                                  child: const Text("취소"),
                                ),
                                CupertinoDialogAction(
                                  onPressed: _onDeleteVideo,
                                  isDestructiveAction: true,
                                  child: const Text("삭제"),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const VideoButton(
                          icon: FontAwesomeIcons.pen,
                          text: "Edit",
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(),
          widget.luckyMode
              ? Positioned(
                  child: Column(
                    children: [
                      Container(
                        width: size.width,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.5),
                        ),
                      ),
                      Container(
                        width: size.width,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.7),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Lucky Mode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: Sizes.size18,
                                ),
                              ),
                              Gaps.v8,
                              Text('5km 이내 무작위(50m 이동 시 새로 고침)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Sizes.size18,
                                  )),
                            ]),
                      ),
                    ],
                  ),
                )
              : Container(),
          Positioned(
            top: 50,
            right: 20,
            child: radarMode
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        radarMode = !radarMode;

                        ref.read(luckyProvider.notifier).setUnLucky();
                      });
                      ref.read(compassProvider.notifier).setCondition();
                    },
                    child: VideoRadar(
                      latitude: widget.videoData.latitude,
                      longitude: widget.videoData.longitude,
                      currentLatitude: widget.currentLatitude,
                      currentLongitude: widget.currentLongitude,
                      createdAt: widget.videoData.createdAt,
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        radarMode = !radarMode;

                        ref.watch(luckyProvider.notifier).setUnLucky();
                      });
                      ref.read(compassProvider.notifier).setCondition();
                    },
                    child: VideoCompass(
                      latitude: widget.videoData.latitude,
                      longitude: widget.videoData.longitude,
                      currentLatitude: widget.currentLatitude,
                      currentLongitude: widget.currentLongitude,
                      createdAt: widget.videoData.createdAt,
                    )),
          ),
          Positioned(
            top: !widget.now ? 90 : 60,
            left: 20,
            child: VideoLocation(
              name: widget.videoData.location,
              address: widget.videoData.address,
              latitude: widget.videoData.latitude,
              longitude: widget.videoData.longitude,
              url: widget.videoData.kakaomapId,
            ),
          ),
          !widget.now
              ? Positioned(
                  top: ref
                          .watch(searchConditionProvider)
                          .searchCondition
                          .isNotEmpty
                      ? 38
                      : 50,
                  left: 20,
                  child: GestureDetector(
                      onTap: () async {
                        ref.watch(luckyProvider.notifier).setUnLucky();
                        await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const SearchScreen());
                      },
                      child: SearchBar(
                        searchcondition:
                            ref.watch(searchConditionProvider).searchCondition,
                      )),
                )
              : Container(),
        ],
      ),
    );
  }
}
