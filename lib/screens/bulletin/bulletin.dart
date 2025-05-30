import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'createpostpage.dart';
import 'post_detail_page.dart';
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
  Stream<QuerySnapshot>? postsStream;

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
          _initializePostsStream(); // userGroupId를 가져온 후 스트림 초기화
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _updatePostsStreamWithSearchQuery();
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
                _initializePostsStream();
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
    if (userGroupId.isEmpty) return; // userGroupId가 없으면 리턴

    if (searchQuery.isEmpty) {
      _initializePostsStream();
    } else {
      setState(() {
        postsStream = FirebaseFirestore.instance
            .collection('posts')
            .where('group_id', isEqualTo: userGroupId)
            .orderBy('title') // 먼저 제목 기준으로 정렬
            .orderBy('created_at', descending: true) // 그 다음 생성 날짜 기준으로 내림차순 정렬
            .where('title_arr', arrayContains: searchQuery)
            .snapshots();
      });
    }
  }

  void _initializePostsStream() {
    if (userGroupId.isEmpty) return; // userGroupId가 없으면 리턴
    
    setState(() {
      postsStream = FirebaseFirestore.instance
          .collection('posts')
          .where('group_id', isEqualTo: userGroupId)
          .orderBy('created_at', descending: true)
          .snapshots();
    });
  }

  // BulletinPage.dart 내 _buildPostList 함수 수정
  Widget _buildPostList() {
    if (userGroupId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder(
      stream: postsStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          print('게시물 목록 로딩 중 에러 발생: ${snapshot.error}');
          return Center(child: Text('에러가 발생했습니다: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('게시물이 없습니다.'));
        }

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
                title: Text(
                  post['title'] ?? '제목 없음',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post['related_work'] != '')
                      Text(
                        '관련 업무: ${post['related_work'] ?? '없음'}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    if (post['related_work'] == '')
                      const SizedBox(height: 10),
                    Text(
                      '설명: ${post['description'] ?? '없음'}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<int>(
                      future: countComments(document.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data! > 0) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.comment),
                              const SizedBox(width: 2),
                              Text('${snapshot.data}'),
                            ],
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    SizedBox.fromSize(size: const Size.square(10)),
                    if (post['image_url'] != null && post['image_url'].isNotEmpty)
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
      // If both contain or don't contain the searchQuery, sort by createdAt
      DateTime createdAtA = (postA['created_at'] as Timestamp).toDate();
      DateTime createdAtB = (postB['created_at'] as Timestamp).toDate();
      int dateComp = createdAtB.isBefore(createdAtA) ? 0 : 1;
      return dateComp;
    }
  }

  Future<int> countComments(String postId) async {
    try {
      final QuerySnapshot commentSnapshot = await FirebaseFirestore.instance
          .collection('comments')
          .where('post_id', isEqualTo: postId)
          .get();

      // 댓글의 개수 반환
      return commentSnapshot.docs.length;
    } catch (e) {
      print('댓글 개수 조회 중 에러 발생: $e');
      return 0;
    }
  }

  Future<String?> selectFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // 선택한 경로를 SharedPreferences에 저장
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('download_directory', selectedDirectory);
        return selectedDirectory;
      }
      return null;
    } catch (e) {
      print('폴더 선택 중 에러 발생: $e');
      return null;
    }
  }

  Future<String?> getSavedDirectory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('download_directory');
    } catch (e) {
      print('저장된 디렉토리 조회 중 에러 발생: $e');
      return null;
    }
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
      print('파일 다운로드 중 에러 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 다운로드 중 오류가 발생했습니다')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGroupUsers() async {
    try {
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
    } catch (e) {
      print('그룹 사용자 조회 중 에러 발생: $e');
      return [];
    }
  }

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
        file_url = file_url ?? [];

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
