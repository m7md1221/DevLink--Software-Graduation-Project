import 'package:flutter/material.dart';

import '../services/media_url.dart';

/// The signed-in user's own avatar, through the signed URL from `Auth/me`.
/// Takes the same `fit` and `errorBuilder` as the `Image.network` it replaces.
class OwnAvatarImage extends StatelessWidget {
  const OwnAvatarImage({super.key, this.fit, required this.errorBuilder});

  final BoxFit? fit;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: MediaUrl.ownAvatar(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return Image.network(MediaUrl.resolve(snapshot.data), fit: fit, errorBuilder: errorBuilder);
      },
    );
  }
}
