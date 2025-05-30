import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'createpostpage_web.dart';
import 'post_detail_page_web.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

// 필요한 추가 import 구문들

class BulletinPage extends StatefulWidget {
  const BulletinPage({super.key});

  @override
  _BulletinPageState createState() => _BulletinPageState();
}

class _BulletinPageState extends State<BulletinPage> {
  String searchQuery = ''; // 검색어를 저장할 변수
  TextEditingController searchController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String userGroupId = '';
  String groupManagerId = '';
  bool? commentExist;
  Future<List<Map<String, dynamic>>>? futureGroupUsers;

  @override
  void initState() {
    super.initState();
    futureGroupUsers = _fetchGroupUsers();
    _fetchUserGroupId();
  }

  void _fetchUserGroupId() async {
    if (currentUser != null) {
      var userDoc =
          await firestore.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        setState(() {
          userGroupId = userDoc.data()!['user_group_id'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    setState(_updatePostsStreamWithSearchQuery);
    return Scaffold(
      appBar: // AppBar에 검색 기능 추가
          AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.brown[100],
        title: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: '포스트 제목 검색...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
              futureGroupUsers = _fetchGroupUsers();
            });
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                searchController.clear();
                searchQuery = '';
                //futureGroupUsers = _fetchGroupUsers();
              });
            },
          ),
          IconButton(
            // 검색 아이콘 버튼 추가
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _updatePostsStreamWithSearchQuery(); // 검색 결과를 새로고침
              });
            },
          ),
        ],
      ),

      body: _buildPostList(), // 게시물 리스트를 빌드하는 함수
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPost, // 새 게시물 작성 함수
        child: const Icon(Icons.add),
      ),
    );
  }

  void _updatePostsStreamWithSearchQuery() {
    if (searchQuery.isEmpty) {
      _initializePostsStream();
    } else {
      postsStream = FirebaseFirestore.instance
          .collection('posts')
          .where('group_id', isEqualTo: userGroupId)
          .orderBy('title') // 먼저 제목 기준으로 정렬
          .orderBy('created_at', descending: true) // 그 다음 생성 날짜 기준으로 내림차순 정렬
          //.where('title', isGreaterThanOrEqualTo: searchQuery) // 검색 쿼리를 제목과 비교
          .where('title_arr', arrayContains: searchQuery)
          .snapshots();
    }
    setState(() {});
  }

  void _initializePostsStream() {
    postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('group_id', isEqualTo: userGroupId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot>? postsStream;

  // BulletinPage.dart 내 _buildPostList 함수 수정
  Widget _buildPostList() {
    return StreamBuilder(
      stream: postsStream,
      // 기존 StreamBuilder 코드 ...
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        // 기존 코드 ...
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        } else {
          return ListView.separated(
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1.5,
              color: Color(0xffcccccc),
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              List<DocumentSnapshot> sortedDocuments =
                  snapshot.data!.docs.toList()..sort(customSort);

              DocumentSnapshot document = sortedDocuments[index];
              Map<String, dynamic> post =
                  document.data() as Map<String, dynamic>;
              return SizedBox(
                height: 110,
                child: ListTile(

                  title: Text(post['title'] ?? '제목 없음',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post['related_work'] != '')
                      Text('관련 업무: ${post['related_work'] ?? '없음'}',
                          overflow: TextOverflow.ellipsis,
                        maxLines: 1,),
                      if (post['related_work'] == '')
                        const SizedBox(height: 10),
                      Text('설명: ${post['description'] ?? '없음'}',
                          overflow: TextOverflow.ellipsis,
                      maxLines: 2,),
                      const SizedBox(height: 10,),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<int>(
                        future: countComments(document.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data! > 0) {
                            // 댓글이 1개 이상 있는 경우 아이콘과 댓글 개수 표시
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              // Row의 크기를 자식들의 크기에 맞게 조절
                              children: [
                                const Icon(Icons.comment), // 댓글 아이콘
                                const SizedBox(width: 2), // 아이콘과 텍스트 사이 간격
                                Text('${snapshot.data}'), // 댓글 개수 표시
                              ],
                            );
                          } else {
                            // 댓글이 없는 경우
                            return const SizedBox.shrink(); // 또는 다른 위젯
                          }
                        },
                      ),
                      SizedBox.fromSize(size: const Size.square(10)),
                      if (post['image_url'] != null &&
                          post['image_url'].isNotEmpty)
                        const Icon(Icons.image),
                      SizedBox.fromSize(
                        size: const Size.square(12),
                      ),
                      if (post['file_url'] != null && post['file_url'].isNotEmpty)
                        const Icon(Icons.file_copy),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          PostDetailPage(post: post, documentId: document.id))),
                ),
              );
            },
          );
        }
      },
    );
  }

  int customSort(DocumentSnapshot a, DocumentSnapshot b) {
    Map<String, dynamic> postA = a.data() as Map<String, dynamic>;
    Map<String, dynamic> postB = b.data() as Map<String, dynamic>;

    // Check if titles of postA and postB contain the searchQuery
    bool containsSearchQueryA = postA['title']?.contains(searchQuery) ?? false;
    bool containsSearchQueryB = postB['title']?.contains(searchQuery) ?? false;

    if (containsSearchQueryA && !containsSearchQueryB) {
      return 0; // postA contains the searchQuery and should come first
    } else if (!containsSearchQueryA && containsSearchQueryB) {
      return 1; // postB contains the searchQuery and should come first
    } else {
      // If both contain or don't contain the searchQuery, sort by created_at
      DateTime createdAtA = (postA['created_at'] as Timestamp).toDate();
      DateTime createdAtB = (postB['created_at'] as Timestamp).toDate();
      int dateComp = createdAtB.isBefore(createdAtA) ? 0 : 1;
      return dateComp;
    }
  }

  Future<int> countComments(String postId) async {
    final QuerySnapshot commentSnapshot = await FirebaseFirestore.instance
        .collection('comments')
        .where('post_id', isEqualTo: postId)
        .get();

    // 댓글의 개수 반환
    return commentSnapshot.docs.length;
  }

  // void _showDownloadDialog(BuildContext context, String url, String type) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('$type 다운로드'),
  //       content: Text('해당 $type를 다운로드하시겠습니까?'),
  //       actions: <Widget>[
  //         TextButton(
  //           child: const Text('취소'),
  //           onPressed: () => Navigator.of(context).pop(),
  //         ),
  //         TextButton(
  //           child: const Text('열기'),
  //           onPressed: () async {
  //             if (await canLaunch(url)) {
  //               await launch(url);
  //             } else {
  //               print('Could not launch $url');
  //             }
  //             Navigator.of(context).pop();
  //           },
  //         ),
  //         TextButton(
  //           child: const Text('다운로드'),
  //           onPressed: () async {
  //             if (await canLaunch(url)) {
  //               await downloadFile(url, context);
  //             } else {
  //               print('Could not launch $url');
  //             }
  //             Navigator.of(context).pop();
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<String?> selectFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // 선택한 경로를 SharedPreferences에 저장
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_directory', selectedDirectory);
      return selectedDirectory;
    }
    return null;
  }

  Future<String?> getSavedDirectory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('download_directory');
  }

  Future<void> downloadFile(String url, BuildContext context) async {
    Dio dio = Dio();
    String? directoryPath = await getSavedDirectory();

    if (directoryPath == null) {
      // 사용자에게 경로 선택하게 하기
      directoryPath = await selectFolder();
      if (directoryPath == null) {
        return; // 사용자가 경로 선택을 취소한 경우
      }
    }

    try {
      Uri uri = Uri.parse(url);
      String fileName = uri.pathSegments.last;
      await dio.download(url, "$directoryPath/$fileName");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName 다운로드 완료')),
      );
    } catch (e) {
      print(e);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGroupUsers() async {
    QuerySnapshot groupSnapshot;
    groupSnapshot = await firestore
        .collection('groups')
        .where('group_users', arrayContains: currentUser?.uid)
        .get();

    List<Map<String, dynamic>> groupUsers = [];
    for (var groupDoc in groupSnapshot.docs) {
      List<dynamic> userIds = groupDoc['group_users'];
      for (var userId in userIds) {
        var userDoc = await firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          groupUsers.add({
            'uid': userId,
            'user_name': userDoc.data()?['user_name'] ?? '',
            // 필요한 경우 여기에 추가 필드를 포함시킵니다.
          });
        }
      }
    }

    return groupUsers;
  } // related_work 필드가 게시물에 포함되어 있다고 가정합니다.

  void _createNewPost() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const CreatePostPage()));
  }
}

class Post {
  String title;
  String related_work;
  String description;
  List<String> image_url;
  List<String> file_url;
  DateTime created_at;

  Post({
    required this.title,
    required this.related_work,
    required this.description,
    List<String>? image_url,
    List<String>? file_url,
    required this.created_at,
  })  : image_url = image_url ?? [],
        file_url = file_url ?? []; // null 체크 및 초기화

  // Firestore 문서를 Dart 객체로 변환
  factory Post.fromMap(Map<String, dynamic> map, String documentId) {
    return Post(
      title: map['title'] ?? '',
      related_work: map['related_work'] ?? '',
      description: map['description'] ?? '',
      image_url: List<String>.from(map['image_url'] ?? []),
      file_url: List<String>.from(map['file_url'] ?? []),
      created_at: (map['created_at'] as Timestamp).toDate(),
    );
  }

  // Dart 객체를 Firestore 문서로 변환
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'related_work': related_work,
      'description': description,
      'image_url': image_url,
      'file_url': file_url,
      'created_at': created_at,
    };
  }
}
