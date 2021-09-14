import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lemmy_api_client/v3.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import '../../hooks/logged_in_action.dart';
import '../../pages/create_post.dart';
import '../../stores/accounts_store.dart';
import '../../util/icons.dart';
import '../../util/observer_consumers.dart';
import '../bottom_modal.dart';
import '../info_table_popup.dart';
import 'full_post_store.dart';
import 'post_store.dart';

class PostMoreMenuButton extends StatelessWidget {
  const PostMoreMenuButton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: () => showPostMoreMenu(
            context: context,
            postStore: context.read<PostStore>(),
            fullPostStore: null,
          ),
          icon: Icon(moreIcon),
          padding: const EdgeInsets.all(0),
          visualDensity: VisualDensity.compact,
        )
      ],
    );
  }
}

void showPostMoreMenu({
  required BuildContext context,
  required PostStore postStore,
  required FullPostStore? fullPostStore,
}) {
  // TODO: add blocking!
  showBottomModal(
    context: context,
    builder: (context) =>
        PostMoreMenu(postStore: postStore, fullPostStore: fullPostStore),
  );
}

class PostMoreMenu extends HookWidget {
  final PostStore postStore;
  final FullPostStore? fullPostStore;
  const PostMoreMenu({
    required this.postStore,
    required this.fullPostStore,
  });

  @override
  Widget build(BuildContext context) {
    final loggedInAction = useLoggedInAction(postStore.postView.instanceHost);

    final isMine = context
            .read<AccountsStore>()
            .defaultUserDataFor(postStore.postView.instanceHost)
            ?.userId ==
        postStore.postView.creator.id;

    return ObserverBuilder<PostStore>(
        store: postStore,
        builder: (context, store) {
          final post = store.postView;

          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Open in browser'),
                onTap: () async => await ul.canLaunch(post.post.apId)
                    ? ul.launch(post.post.apId)
                    : ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("can't open in browser"))),
              ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () async {
                    final postView = await showCupertinoModalPopup<PostView>(
                      context: context,
                      builder: (_) => CreatePostPage.edit(post.post),
                    );

                    if (postView != null) {
                      store.updatePostView(postView);
                    }
                  },
                )
              else
                ListTile(
                  leading: store.userBlockingState.isLoading
                      ? const CircularProgressIndicator.adaptive()
                      : const Icon(Icons.block),
                  title:
                      Text('${post.creatorBlocked ? 'Unblock' : 'Block'} user'),
                  onTap: () {
                    Navigator.of(context).pop();
                    loggedInAction(store.blockUser)();
                  },
                ),
              if (fullPostStore != null && fullPostStore!.fullPostView != null)
                ObserverBuilder<FullPostStore>(
                  store: fullPostStore,
                  builder: (context, store) {
                    return ListTile(
                      leading: store.communityBlockingState.isLoading
                          ? const CircularProgressIndicator.adaptive()
                          : const Icon(Icons.block),
                      title: Text(
                          '${store.fullPostView!.communityView.blocked ? 'Unblock' : 'Block'} community'),
                      onTap: () {
                        Navigator.of(context).pop();
                        loggedInAction(store.blockCommunity)();
                      },
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Nerd stuff'),
                onTap: () {
                  showInfoTablePopup(context: context, table: {
                    '% of upvotes':
                        '${(100 * (post.counts.upvotes / (post.counts.upvotes + post.counts.downvotes))).toInt()}%',
                    ...post.toJson(),
                  });
                },
              ),
            ],
          );
        });
  }
}
