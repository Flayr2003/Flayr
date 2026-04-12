import 'package:dismissible_page/dismissible_page.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:readmore/readmore.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flayr/common/extensions/string_extension.dart';
import 'package:flayr/common/service/navigation/navigate_with_controller.dart';
import 'package:flayr/common/service/url_extractor/parsers/base_parser.dart';
import 'package:flayr/common/widget/custom_bg_circle_button.dart';
import 'package:flayr/common/widget/custom_image.dart';
import 'package:flayr/common/widget/custom_page_indicator.dart';
import 'package:flayr/common/widget/double_tap_detector.dart';
import 'package:flayr/languages/languages_keys.dart';
import 'package:flayr/model/post_story/post_model.dart';
import 'package:flayr/model/user_model/user_model.dart';
import 'package:flayr/screen/hashtag_screen/hashtag_screen.dart';
import 'package:flayr/screen/image_view_screen/image_view_screen.dart';
import 'package:flayr/screen/post_screen/single_post_screen.dart';
import 'package:flayr/screen/post_screen/widget/url_card.dart';
import 'package:flayr/screen/reels_screen/reels_screen.dart';
import 'package:flayr/utilities/app_res.dart';
import 'package:flayr/utilities/asset_res.dart';
import 'package:flayr/utilities/font_res.dart';
import 'package:flayr/utilities/text_style_custom.dart';
import 'package:flayr/utilities/theme_res.dart';

class PostViewCenter extends StatelessWidget {
  final Post post;
  final void Function()? onHeartAnimationEnd;
  final Function(TapDownDetails) onDoubleTap;

  const PostViewCenter(
      {super.key,
      required this.post,
      this.onHeartAnimationEnd,
      required this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.to(() => SinglePostScreen(post: post, isFromNotification: false));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((post.description ?? '').isNotEmpty)
            PostTextView(
                description: post.descriptionWithUserName,
                mentionUsers: post.mentionedUsers ?? [],
                metadata: post.metaData),
          if ((post.images ?? []).isNotEmpty)
            PostImageView(
              post: post,
              onDoubleTap: onDoubleTap,
              onHeartAnimationEnd: onHeartAnimationEnd,
            ),
          if ((post.video ?? '').isNotEmpty)
            PostVideoView(
              post: post,
              onDoubleTap: onDoubleTap,
              onHeartAnimationEnd: onHeartAnimationEnd,
            )
        ],
      ),
    );
  }
}

class PostTextView extends StatefulWidget {
  final String? description;
  final List<User> mentionUsers;
  final Color? basicTextColor;
  final Color? hashtagTextColor;
  final Color? mentionTextColor;
  final double? basicTextOpacity;
  final UrlMetadata? metadata;

  const PostTextView(
      {super.key,
      required this.description,
      required this.mentionUsers,
      this.basicTextColor,
      this.hashtagTextColor,
      this.mentionTextColor,
      this.basicTextOpacity,
      this.metadata});

  @override
  State<PostTextView> createState() => _PostTextViewState();
}

class _PostTextViewState extends State<PostTextView> {
  ValueNotifier<bool> isCollapsed = ValueNotifier(true);

  @override
  Widget build(BuildContext context) {
    TextStyle collapsedStyle = TextStyleCustom.outFitLight300(
        fontSize: 15,
        color: widget.basicTextColor ?? textLightGrey(context),
        opacity: .8);

    return InkWell(
      onTap: () {
        isCollapsed.value = !isCollapsed.value;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadMoreText(
            widget.description ?? '',
            isCollapsed: isCollapsed,
            trimMode: TrimMode.Line,
            trimLines: AppRes.trimLine,
            colorClickableText: Colors.pink,
            trimCollapsedText: LKey.more.tr,
            trimExpandedText: ' ${LKey.less.tr}',
            lessStyle: collapsedStyle,
            moreStyle: collapsedStyle,
            style: TextStyleCustom.outFitRegular400(
                color: widget.basicTextColor ?? textDarkGrey(context),
                fontSize: 15,
                opacity: widget.basicTextOpacity),
            annotations: [
              Annotation(
                regExp: AppRes.hashTagRegex,
                spanBuilder: ({required String text, TextStyle? textStyle}) =>
                    TextSpan(
                        text: text,
                        style: textStyle?.copyWith(
                          color: widget.hashtagTextColor ??
                              themeAccentSolid(context),
                          fontFamily: FontRes.outFitMedium500,
                          fontSize: 15,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(() => HashtagScreen(hashtag: text, index: 1),
                                preventDuplicates: false);
                          }),
              ),
              Annotation(
                regExp: AppRes.urlRegex,
                spanBuilder: ({required String text, TextStyle? textStyle}) =>
                    TextSpan(
                        text: text,
                        style: textStyle?.copyWith(
                          color: themeAccentSolid(context),
                          fontFamily: FontRes.outFitMedium500,
                          fontSize: 15,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            await text.lunchUrlWithHttps;
                          }),
              ),
              Annotation(
                regExp: AppRes.userNameRegex,
                spanBuilder: ({required String text, TextStyle? textStyle}) {
                  return TextSpan(
                    text: text,
                    style: textStyle?.copyWith(
                      color: widget.mentionTextColor ?? blueFollow(context),
                      fontFamily: FontRes.outFitMedium500,
                      fontSize: 15,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        String id = text.replaceAll('@', '');
                        User? mentionUser = widget.mentionUsers
                            .firstWhereOrNull(
                                (element) => element.username == id);
                        if (mentionUser != null) {
                          NavigationService.shared
                              .openProfileScreen(mentionUser);
                        }
                      },
                  );
                },
              ),
            ],
          ),
          if (widget.metadata != null) UrlCard(metadata: widget.metadata)
        ],
      ),
    );
  }
}

class PostImageView extends StatelessWidget {
  final Post post;
  final double height;
  final EdgeInsets? margin;
  final double? radius;
  final Function(TapDownDetails)? onDoubleTap;
  final void Function()? onHeartAnimationEnd;

  const PostImageView(
      {super.key,
      required this.post,
      this.height = 300,
      this.margin,
      this.radius,
      this.onHeartAnimationEnd,
      this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    RxInt selectedIndex = 0.obs;
    PageController controller = PageController();
    GlobalKey uniqueTag = GlobalKey();
    return DoubleTapDetector(
      onDoubleTap: (details) {
        if (onDoubleTap != null) {
          onDoubleTap?.call(details);
        }
      },
      child: Container(
        margin: margin ?? const EdgeInsets.only(right: 10.0, top: 10),
        constraints: BoxConstraints(
            maxHeight: height,
            minHeight: height,
            maxWidth: MediaQuery.of(context).size.width,
            minWidth: MediaQuery.of(context).size.width),
        child: ClipSmoothRect(
          radius:
              SmoothBorderRadius(cornerRadius: radius ?? 8, cornerSmoothing: 1),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PageView.builder(
                controller: controller,
                onPageChanged: (value) {
                  selectedIndex.value = value;
                },
                itemCount: (post.images ?? []).length,
                itemBuilder: (context, index) {
                  Images? image = post.images?[index];
                  return Hero(
                    tag: '${uniqueTag}_${image?.image}',
                    child: CustomImage(
                        size: Size(MediaQuery.of(context).size.width, 300),
                        image: image?.image?.addBaseURL(),
                        radius: 0,
                        isShowPlaceHolder: true,
                        cornerSmoothing: 1),
                  );
                },
              ),
              if ((post.images ?? []).length > 1)
                CustomPageIndicator(
                    length: (post.images ?? []).length,
                    selectedIndex: selectedIndex),
              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: InkWell(
                  onTap: () {
                    context.pushTransparentRoute(ImageViewScreen(
                      images: post.images ?? [],
                      selectedIndex: selectedIndex.value,
                      onChanged: (position) {
                        controller.jumpToPage(position);
                      },
                      tag: '$uniqueTag',
                    ));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CustomBgCircleButton(
                        image: AssetRes.icExpand, size: Size(30, 30)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class PostVideoView extends StatefulWidget {
  final Post? post;
  final EdgeInsets? margin;
  final double? radius;
  final Function(TapDownDetails)? onDoubleTap;
  final void Function()? onHeartAnimationEnd;
  final bool isFromChat;

  const PostVideoView(
      {super.key,
      required this.post,
      this.onHeartAnimationEnd,
      this.onDoubleTap,
      this.margin,
      this.radius,
      this.isFromChat = false});

  @override
  State<PostVideoView> createState() => _PostVideoViewState();
}

class _PostVideoViewState extends State<PostVideoView> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  void _initVideoPlayer() {
    final videoUrl = widget.post?.video?.addBaseURL();
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..setLooping(true)
        ..setVolume(0) // Start muted
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('post-video-${widget.post?.id ?? widget.post?.video}'),
      onVisibilityChanged: (info) {
        if (!mounted || _controller == null || !_isInitialized) return;
        if (info.visibleFraction > 0.5) {
          _controller?.play();
        } else {
          _controller?.pause();
        }
      },
      child: DoubleTapDetector(
        onDoubleTap: (details) {
          if (widget.onDoubleTap != null) {
            widget.onDoubleTap?.call(details);
          }
        },
        onTap: widget.isFromChat
            ? null
            : () {
                _controller?.pause();
                Get.to(() => ReelsScreen(reels: [widget.post!].obs, position: 0));
              },
        child: Container(
          margin: widget.margin ?? const EdgeInsets.only(right: 10.0, top: 10),
          constraints: BoxConstraints(
              maxHeight: 211,
              minHeight: 211,
              maxWidth: MediaQuery.of(context).size.width,
              minWidth: MediaQuery.of(context).size.width),
          child: ClipSmoothRect(
            radius: SmoothBorderRadius(
                cornerRadius: widget.radius ?? 10, cornerSmoothing: 1),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video player or thumbnail fallback
                if (_isInitialized && _controller != null)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                else
                  CustomImage(
                    size: const Size(double.infinity, 211),
                    fit: BoxFit.cover,
                    radius: widget.radius ?? 10,
                    cornerSmoothing: 1,
                    image: widget.post?.thumbnail?.addBaseURL(),
                  ),
                // Mute/unmute button
                if (_isInitialized)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          _controller?.setVolume(_isMuted ? 0 : 1);
                        });
                      },
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                // Play indicator (only when not initialized)
                if (!_isInitialized)
                  Container(
                    height: 35,
                    width: 35,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: textDarkGrey(context).withValues(alpha: .4)),
                    alignment: Alignment.center,
                    child: Image.asset(AssetRes.icPlay, width: 20, height: 20),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
