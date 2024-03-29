import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surfify/features/video/models/video_model.dart';
import 'package:surfify/features/video/view_models/hashtag_view_model.dart';
import 'package:surfify/features/video/view_models/here_view_model.dart';
import 'package:surfify/features/video/view_models/lucky_view_model.dart';
import 'package:surfify/features/video/view_models/random_view_model.dart';
import 'package:surfify/features/video/view_models/search_condition_view_model.dart';
import 'package:surfify/features/video/views/search_screen.dart';
import 'package:surfify/features/video/views/widgets/overview.dart';
import 'package:surfify/features/video/views/widgets/search_bar.dart';
import 'package:surfify/features/video/views/widgets/video_post.dart';

import '../../../constants/sizes.dart';
import '../view_models/compass_view_model.dart';
import '../view_models/direction_view_model.dart';
import '../view_models/place_view_model.dart';

class VideoTimelineScreen extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;
  const VideoTimelineScreen(
      {super.key, required this.latitude, required this.longitude});

  @override
  createState() => VideoTimelineScreenState();
}

class VideoTimelineScreenState extends ConsumerState<VideoTimelineScreen> {
  int _itemCount = 0;
  bool overViewMode = false;

  double _scaleFactor = 1;
  double _baseScaleFactor = 1;

  final PageController _pageController_vertical = PageController();
  final PageController _pageController_horizontal = PageController();

  final Duration _scrollDuration = const Duration(milliseconds: 250);
  final Curve _scrollCurve = Curves.linear;

  void _onPageChanged(int page) {
    _pageController_vertical.animateToPage(
      page,
      duration: _scrollDuration,
      curve: _scrollCurve,
    );
    if (page == _itemCount - 1) {
      //수정해야함
      setState(() {});
    }
  }

  void _onPageChanged2(int page) {
    _pageController_horizontal.animateToPage(
      page,
      duration: _scrollDuration,
      curve: _scrollCurve,
    );
    if (page == _itemCount - 1) {
      // 넣어야 함
      setState(() {});
    }
  }

  void _onVideoFinished() {
    _pageController_vertical.nextPage(
      duration: _scrollDuration,
      curve: _scrollCurve,
    );
  }

  bool checkUserandHashTags(
      List<String> list, String username, List<String> elements) {
    return elements.sublist(1).every((element) => list.contains(element)) &&
        username == elements[0];
  }

  bool checkHashTags(List<String> list, List<String> elements) {
    return elements.every((element) => list.contains(element));
  }

  List<String> substringFromIndex(List<String> inputList) {
    List<String> result = [];
    for (String element in inputList) {
      if (element.length > 1) {
        result.add(element.substring(1));
      }
    }

    return result;
  }

  double _direction = 0.00;
  int heading = 1;

  StreamSubscription<CompassEvent>? stream;

  void _handleCompassEvent(CompassEvent event) {
    if (ref.watch(compassProvider) || overViewMode) {
      _direction = event.heading ?? 0.0;
      var prev = heading;
      if (_direction >= 315 || _direction <= 45) {
        heading = 1;
      }
      if (_direction > 45 && _direction <= 135) {
        heading = 2;
      }
      if (_direction > 135 && _direction <= 225) {
        heading = 3;
      }
      if (_direction > 225 && _direction <= 315) {
        heading = 4;
      }
      if (prev != heading) {
        setState(() {
          ref
              .watch(directionProvider(
                      '${widget.longitude},${widget.latitude},$heading')
                  .notifier)
              .refresh(heading, '${widget.longitude},${widget.latitude}');
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    stream = FlutterCompass.events?.listen(_handleCompassEvent);
  }

  @override
  void dispose() {
    stream?.cancel();
    _pageController_vertical.dispose();
    _pageController_horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchCondition = ref.watch(searchConditionProvider).searchCondition;
    return GestureDetector(
      onScaleStart: (details) {
        _baseScaleFactor = _scaleFactor;
      },
      onScaleUpdate: (details) {
        _scaleFactor = _baseScaleFactor * details.scale;
        print(details.scale);
        if (details.scale < 0.7) {
          setState(() {
            overViewMode = true;
          });
        } else if (details.scale >= 1.2) {
          setState(() {
            overViewMode = false;
          });
        }
      },
      child: Stack(children: [
        ref.watch(searchConditionProvider).searchCondition.isEmpty
            ? ref.watch(luckyProvider) // lucky mode
                ? ref
                    .watch(randomProvider(
                        '${widget.longitude},${widget.latitude}'))
                    .when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (error, stackTrace) => Center(
                        child: Text(
                          'Could not load videos: $error',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      data: (locations) => RefreshIndicator(
                        onRefresh: () => ref
                            .watch(randomProvider(
                                    '${widget.longitude},${widget.latitude}')
                                .notifier)
                            .refresh(
                                '${widget.longitude},${widget.latitude}'), //수정
                        displacement: 50,
                        edgeOffset: 20,
                        color: Theme.of(context).primaryColor,
                        child: PageView.builder(
                          controller: _pageController_vertical,
                          scrollDirection: Axis.vertical,
                          onPageChanged: _onPageChanged,
                          itemCount: locations.length,
                          itemBuilder: (context, index) => ref
                              .watch(placeProvider(locations[index]))
                              .when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                                error: (error, stackTrace) => Center(
                                  child: Text(
                                    'Could not load videos: $error',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                data: (videos) {
                                  print("luckymode ${videos.length}");
                                  final random = Random();
                                  final videoData =
                                      videos[random.nextInt(videos.length)];
                                  // final videoData = videos[index];
                                  return VideoPost(
                                    onVideoFinished: _onVideoFinished,
                                    index: index,
                                    videoData: videoData,
                                    radar: true,
                                    now: false,
                                    luckyMode: true,
                                    currentLatitude: widget.latitude,
                                    currentLongitude: widget.longitude,
                                  );
                                },
                              ),
                        ),
                      ),
                    )
                : ref.watch(compassProvider)
                    ? ref
                        .watch(directionProvider(
                            '${widget.longitude},${widget.latitude},$heading'))
                        .when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stackTrace) => Center(
                            child: Text(
                              'Could not load videos: $error',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          data: (locations) => (locations.isEmpty)
                              ? const Center(
                                  child: Text(
                                    '이 방향으로는 서핑포인트가 없어요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Sizes.size24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () => ref
                                      .watch(hereProvider(
                                              '${widget.longitude},${widget.latitude}')
                                          .notifier)
                                      .refresh(
                                          '${widget.longitude},${widget.latitude}'),
                                  displacement: 50,
                                  edgeOffset: 20,
                                  color: Theme.of(context).primaryColor,
                                  child: PageView.builder(
                                    controller: _pageController_vertical,
                                    scrollDirection: Axis.vertical,
                                    onPageChanged: _onPageChanged,
                                    itemCount: locations.length,
                                    itemBuilder: (context, index) => ref
                                        .watch(placeProvider(locations[index]))
                                        .when(
                                          loading: () => const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                          error: (error, stackTrace) => Center(
                                            child: Text(
                                              'Could not load videos: $error',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                          data: (videos) {
                                            _itemCount = videos.length;
                                            return RefreshIndicator(
                                              onRefresh: ref
                                                  .watch(placeProvider(
                                                          locations[index])
                                                      .notifier)
                                                  .refresh,
                                              displacement: 50,
                                              edgeOffset: 20,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              child: PageView.builder(
                                                controller:
                                                    _pageController_horizontal,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                onPageChanged: _onPageChanged2,
                                                itemCount: videos.length,
                                                itemBuilder: (context, index) {
                                                  final videoData =
                                                      videos[index];
                                                  return VideoPost(
                                                    onVideoFinished: () {},
                                                    index: index,
                                                    videoData: videoData,
                                                    radar: false,
                                                    now: false,
                                                    luckyMode: false,
                                                    currentLatitude:
                                                        widget.latitude,
                                                    currentLongitude:
                                                        widget.longitude,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                  ),
                                ),
                        )
                    : overViewMode
                        ? ref
                            .watch(directionProvider(
                                '${widget.longitude},${widget.latitude},$heading'))
                            .when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, stackTrace) => Center(
                                child: Text(
                                  'Could not load videos: $error',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              data: (data) {
                                return Overview(
                                  ref: ref,
                                  data: data,
                                  latitude: widget.latitude,
                                  longitude: widget.longitude,
                                );
                              },
                            )
                        : ref
                            .watch(hereProvider(
                                '${widget.longitude},${widget.latitude}'))
                            .when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, stackTrace) => Center(
                                child: Text(
                                  'Could not load videos: $error',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              data: (locations) => RefreshIndicator(
                                onRefresh: () => ref
                                    .watch(hereProvider(
                                            '${widget.longitude},${widget.latitude}')
                                        .notifier)
                                    .refresh(
                                        '${widget.longitude},${widget.latitude}'),
                                displacement: 50,
                                edgeOffset: 20,
                                color: Theme.of(context).primaryColor,
                                child: PageView.builder(
                                  controller: _pageController_vertical,
                                  scrollDirection: Axis.vertical,
                                  onPageChanged: _onPageChanged,
                                  itemCount: locations.length,
                                  itemBuilder: (context, index) => ref
                                      .watch(placeProvider(locations[index]))
                                      .when(
                                        loading: () => const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                        error: (error, stackTrace) => Center(
                                          child: Text(
                                            'Could not load videos: $error',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        data: (videos) {
                                          _itemCount = videos.length;
                                          return RefreshIndicator(
                                            onRefresh: ref
                                                .watch(placeProvider(
                                                        locations[index])
                                                    .notifier)
                                                .refresh,
                                            displacement: 50,
                                            edgeOffset: 20,
                                            color:
                                                Theme.of(context).primaryColor,
                                            child: PageView.builder(
                                              controller:
                                                  _pageController_horizontal,
                                              scrollDirection: Axis.horizontal,
                                              onPageChanged: _onPageChanged2,
                                              itemCount: videos.length,
                                              itemBuilder: (context, index) {
                                                final videoData = videos[index];
                                                return VideoPost(
                                                  onVideoFinished: () {},
                                                  index: index,
                                                  videoData: videoData,
                                                  radar: true,
                                                  now: false,
                                                  luckyMode: false,
                                                  currentLatitude:
                                                      widget.latitude,
                                                  currentLongitude:
                                                      widget.longitude,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                ),
                              ),
                            )
            : ref.watch(hashTagProvider(searchCondition)).when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => Center(
                    child: Text(
                      'Could not load videos: $error',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  data: (videos) {
                    late final List<VideoModel> filteredVideos;
                    if (searchCondition[0].startsWith('@') && // 유저만
                        searchCondition.length == 1) {
                      filteredVideos = videos;
                    } else if (searchCondition[0].startsWith('@')) {
                      //유저랑 해시태그
                      filteredVideos = videos
                          .where((video) => checkUserandHashTags(
                              video.hashtag,
                              video.creator,
                              substringFromIndex(searchCondition)))
                          .toList();
                    } else {
                      // 해시태그만
                      filteredVideos = videos
                          .where((video) => checkHashTags(video.hashtag,
                              substringFromIndex(searchCondition)))
                          .toList();
                    }
                    if (filteredVideos.isEmpty) {
                      return RefreshIndicator(
                          onRefresh: ref
                              .watch(hashTagProvider(searchCondition).notifier)
                              .refresh,
                          displacement: 50,
                          edgeOffset: 20,
                          color: Theme.of(context).primaryColor,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 38,
                                left: 20,
                                child: GestureDetector(
                                  onTap: () async {
                                    await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            const SearchScreen());
                                  },
                                  child: SearchBar(
                                      searchcondition: searchCondition),
                                ),
                              ),
                              const Center(
                                child: Text(
                                  '검색 결과가 없어요!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ));
                    }

                    return RefreshIndicator(
                      onRefresh: ref
                          .watch(hashTagProvider(searchCondition).notifier)
                          .refresh,
                      displacement: 50,
                      edgeOffset: 20,
                      color: Theme.of(context).primaryColor,
                      child: PageView.builder(
                        controller: _pageController_vertical,
                        scrollDirection: Axis.vertical,
                        onPageChanged: _onPageChanged,
                        itemCount: filteredVideos.length,
                        itemBuilder: (context, index) {
                          final videoData = filteredVideos[index];
                          return VideoPost(
                            onVideoFinished: () {},
                            index: index,
                            videoData: videoData,
                            radar: true,
                            now: false,
                            luckyMode: false,
                            currentLatitude: widget.latitude,
                            currentLongitude: widget.longitude,
                          );
                        },
                      ),
                    );
                  },
                )
      ]),
    );
  }
}
