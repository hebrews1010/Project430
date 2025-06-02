import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String documentId;

  const PostDetailPage({
    super.key,
    required this.post,
    required this.documentId,
  });

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Map<String, dynamic> _post;
  bool _isEditMode = false; // 수정 모드 상태 표시
  late TextEditingController _titleController;
  late TextEditingController _relatedWorkController;
  late TextEditingController _descriptionController;
  List<XFile> _newSelectedImages = [];
  List<XFile> _newSelectedFiles = [];

  List<String> _markedForDeletionImages = [];
  List<String> _markedForDeletionFiles = [];
  String? _attachedFileUrl;
  bool ing = false;
  bool isLoading = false;
  FirebaseStorage storage = FirebaseStorage.instanceFor(
    bucket: 'gs://four-thirty.firebasestorage.app',
  );

  // ✨ 추가: FocusNode 선언 ✨
  final FocusNode _commentFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _titleController = TextEditingController(text: _post['title']);
    _relatedWorkController = TextEditingController(text: _post['related_work']);
    _descriptionController = TextEditingController(text: _post['description']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _relatedWorkController.dispose();
    _descriptionController.dispose();
    _commentController.dispose(); // ✨ 추가: commentController dispose ✨
    _commentFocusNode.dispose(); // ✨ 추가: FocusNode dispose ✨
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('게시물 수정'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _post = widget.post;
                _titleController = TextEditingController(text: _post['title']);
                _relatedWorkController = TextEditingController(
                  text: _post['related_work'],
                );
                _descriptionController = TextEditingController(
                  text: _post['description'],
                );
                _newSelectedImages = [];
                _newSelectedFiles = [];

                _markedForDeletionImages = [];
                _markedForDeletionFiles = [];

                _isEditMode = false;
              });
            },
          ),
          actions: [
            if (ing == true)
              const CircularProgressIndicator()
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  setState(() {
                    ing = true;
                  });
                  _deleteSelectedMedia();
                  _savePost();
                },
              ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '내용'),
                  maxLines: null,
                  style: const TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickNewImages,
                  child: const Text('이미지 첨부'),
                ),
                const SizedBox(height: 20),
                Wrap(
                  children: [
                    ..._post['image_url']
                        .where(
                          (image_url) =>
                      !_markedForDeletionImages.contains(image_url),
                    )
                        .map<Widget>((image_url) {
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            width: 0.4 * MediaQuery.of(context).size.width,
                            padding: const EdgeInsets.all(5),
                            child: Image.network(
                              image_url,
                              fit: BoxFit.cover,
                              errorBuilder: (
                                  BuildContext context,
                                  Object exception,
                                  StackTrace? stackTrace,
                                  ) {
                                return Image.asset(
                                  'assets/noimage.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                _markedForDeletionImages.add(image_url);
                              });
                            },
                          ),
                        ],
                      );
                    })
                        .toList(),
                  ],
                ),
                ..._newSelectedImages.map<Widget>((image) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 0.4 * MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.all(5),
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                          errorBuilder: (
                              BuildContext context,
                              Object exception,
                              StackTrace? stackTrace,
                              ) {
                            return Image.asset(
                              'assets/noimage.png',
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _newSelectedImages.remove(image);
                          });
                        },
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickNewFiles,
                  child: const Text('파일 첨부'),
                ),
                ...(_post['file_url'] as List<dynamic>).map((file_url) {
                  if (!_markedForDeletionFiles.contains(file_url)) {
                    return ListTile(
                      title: Text(Uri.parse(file_url).pathSegments.last),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed:
                            () => setState(
                              () => _markedForDeletionFiles.add(file_url),
                        ),
                      ),
                    );
                  } else {
                    return const Text('');
                  }
                }),
                if (!kIsWeb)
                  ...(_newSelectedFiles as List<dynamic>).map((file_url) {
                    if (_newSelectedFiles.contains(file_url)) {
                      return ListTile(
                        title: const Text('new file'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed:
                              () => setState(
                                () => _newSelectedFiles.remove(file_url),
                          ),
                        ),
                      );
                    } else {
                      return const Text('');
                    }
                  }),
              ],
            ),
          ),
        ),
      );
    } else {
      // 표시 모드 UI
      bool isCurrentUser = currentUser?.uid == _post['made_by'];
      String postTitle = _post['title'];
      double dynamicFontSize = postTitle.length >= 23 ? 15 : 20;
      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _post['title'] ?? '제목 없음',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dynamicFontSize),
            ),
            actions:
            isCurrentUser
                ? [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editPost(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context),
              ),
            ]
                : [],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 150,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_post['related_work'] != '')
                        Text('관련 업무: ${_post['related_work'] ?? '없음'}'),
                      const SizedBox(height: 5),
                      SelectableLinkify(
                        contextMenuBuilder: (context, editableTextState) {
                          final List<ContextMenuButtonItem> buttonItems =
                              editableTextState.contextMenuButtonItems;
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: buttonItems,
                          );
                        },
                        onOpen:
                            (link) async =>
                        await _launchURL(Uri.parse(link.url)),
                        text: '${_post['description'] ?? '없음'}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                        ),
                        linkStyle: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildImageSection(),
                      _buildFileSection(),
                    ],
                  ),
                ),
                _buildCommentSection(),
                const SizedBox(height: 400),
              ],
            ),
          ),
          bottomSheet: _buildCommentInputField(),
        ),
      );
    }
  }

  RegExp regExp = RegExp(r'^[\d-]+$');

  _launchURL(Uri url) async {
    if (url.toString().startsWith('http')) {
      if (await canLaunchUrl(url)) {
        launchUrl(url);
      } else {
        print("Can't launch $url");
      }
    } else if (regExp.hasMatch(url.toString())) {
      final telUrl = Uri.parse(url.toString());
      launchUrl(telUrl);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('링크를 열 수 없습니다: $url')));
    }
  }

  Widget _buildImageSection() {
    if (_post['image_url'] != null &&
        (_post['image_url'] as List<dynamic>).isNotEmpty) {
      List<dynamic> image_urls = _post['image_url'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이미지', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...List.generate(image_urls.length, (index) {
            String image_url = image_urls[index];
            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 0.4 * MediaQuery.of(context).size.width,
                      child: Image.network(
                        image_url,
                        fit: BoxFit.cover,
                        errorBuilder: (
                            BuildContext context,
                            Object exception,
                            StackTrace? stackTrace,
                            ) {
                          return Image.asset(
                            'assets/noimage.png',
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap:
                          () => _showDownloadDialog(context, image_url, '이미지'),
                      child: const Text(
                        '이미지 다운로드',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
            );
          }),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildFileSection() {
    if (_post['file_url'] != null &&
        (_post['file_url'] as List<dynamic>).isNotEmpty) {
      List<dynamic> file_urls = _post['file_url'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('첨부파일', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...List.generate(file_urls.length, (index) {
            String file_url = file_urls[index];
            return Row(
              children: [
                InkWell(
                  onTap: () => _openFile(file_url),
                  child: SizedBox(
                    width: 0.5 * MediaQuery.of(context).size.width,
                    child: Text(
                      Uri.parse(file_url).pathSegments.last,
                      style: const TextStyle(color: Colors.blue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                InkWell(
                  onTap: () => _showDownloadDialog(context, file_url, '파일'),
                  child: const Text(
                    '파일 다운로드',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildCommentSection() {
    return StreamBuilder(
      stream:
      FirebaseFirestore.instance
          .collection('comments')
          .where('post_id', isEqualTo: widget.documentId)
          .orderBy('created_at', descending: false)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          print('댓글 데이터 가져오기 에러: ${snapshot.error}');
          return const Center(child: Text('댓글을 불러오는데 실패했습니다'));
        }
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        } else {
          return Column(
            children:
            snapshot.data!.docs.map((document) {
              bool isCommentOwner = currentUser?.uid == document['made_by'];
              return ListTile(
                leading: Text(document['user_name'] + ':'),
                title: SelectableText(
                  document['title'],
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
                subtitle:
                document['file_url'] != ''
                    ? InkWell(
                  child: const Text('파일 다운로드'),
                  onTap:
                      () => _showDownloadDialog(
                    context,
                    document['file_url'],
                    '파일',
                  ),
                )
                    : null,
                trailing:
                isCommentOwner
                    ? IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed:
                      () => _confirmDeleteComment(
                    context,
                    document.id,
                    document['file_url'],
                  ),
                )
                    : null,
              );
            }).toList(),
          );
        }
      },
    );
  }

  void _showDownloadDialog(BuildContext context, String url, String type) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        title: Text('$type 다운로드'),
        content: Text('해당 $type를 다운로드하시겠습니까?'),
        actions: <Widget>[
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('다운로드'),
            onPressed: () async {
              try {
                await downloadFile(url, context);
                Uri uri = Uri.parse(url);
                String fileName = uri.pathSegments.last;
                // 파일명에서 앞 4글자를 삭제 (UUID 처리)
                if (fileName.length > 4) {
                  fileName = fileName.substring(4);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$fileName 다운로드 완료')),
                );
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('다운로드 에러: $e')));
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(
      BuildContext context,
      String commentId,
      String? file_url,
      ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('댓글 삭제 확인'),
          content: const Text('이 댓글을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () {
                _deleteComment(commentId, file_url);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteComment(String commentId, String? file_url) async {
    if (file_url != '' && file_url != null) {
      try {
        await FirebaseStorage.instance.refFromURL(file_url).delete();
      } catch (e) {
        print("파일 삭제 에러 (Storage): $e");
      }
    }
    await FirebaseFirestore.instance
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  Widget _buildCommentInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode, // ✨ FocusNode 연결 ✨
              decoration: const InputDecoration(
                hintText: '댓글 입력...',
              ),
              onSubmitted: (value)  { // ✨ async 키워드 추가 ✨
                 _submitComment(); // ✨ await 추가 ✨
                // _submitComment() 내부에서 _commentController.clear()와 _commentFocusNode.requestFocus()가 호출됩니다.
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _pickAndUploadFile();
            },
          ),
          if (isLoading)
            const CircularProgressIndicator()
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitComment,
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        isLoading = true;
      });
      try {
        String file_url = await _uploadFileToStorage(file, 'FourThirty');
        _submitAttachment(file_url);
      } catch (e) {
        print('파일 업로드 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 업로드 실패: $e')),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _submitAttachment(String file_url) async {
    setState(() {
      _attachedFileUrl = file_url;
    });
  }

  String userName = '';

  Future<void> _getUsersNames(String? userUid) async {
    if (userUid == null) {
      userName = 'Unknown';
      return;
    }
    var userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userUid).get();
    userName = userDoc.data()?['user_name'] ?? 'Unknown';
  }

  void _submitComment() async {
    if (_commentController.text.isEmpty && _attachedFileUrl == null) {
      return;
    }

    await _getUsersNames(currentUser?.uid);
    String commentText = _commentController.text;

    Map<String, dynamic> commentData = {
      'post_id': widget.documentId,
      'title': commentText,
      'created_at': DateTime.now(),
      'made_by': currentUser?.uid,
      'user_name': userName,
      'file_url': _attachedFileUrl ?? '',
    };

    try {
      await FirebaseFirestore.instance
          .collection('comments')
          .add(commentData);
    } catch (e) {
      print('댓글 저장 중 에러 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 저장 실패: $e')),
      );
    } finally {
      // ✨ 항상 실행되도록 finally 블록으로 이동 ✨
      _commentController.clear();
      setState(() {
        _attachedFileUrl = null;
      });
      _commentFocusNode.requestFocus(); // ✨ 포커스 재요청 ✨
    }
  }


  Future<String?> selectFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
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

  void _deleteSelectedMedia() async {
    setState(() {
      ing = true;
    });

    try {
      List<String> currentImageUrls = List<String>.from(_post['image_url'] ?? []);
      _post['image_url'] = currentImageUrls
          .where((url) => !_markedForDeletionImages.contains(url))
          .toList();

      List<String> currentFileUrls = List<String>.from(_post['file_url'] ?? []);
      _post['file_url'] = currentFileUrls
          .where((url) => !_markedForDeletionFiles.contains(url))
          .toList();

      for (var file_url in _markedForDeletionFiles) {
        if (file_url != null && file_url.isNotEmpty) {
          try {
            var fileRef = storage.refFromURL(file_url);
            await fileRef.delete();
            print("Deleted file from storage: $file_url");
          } catch (e) {
            print("Error deleting file from storage ($file_url): $e");
          }
        }
      }

      for (var image_url in _markedForDeletionImages) {
        if (image_url != null && image_url.isNotEmpty) {
          try {
            var imageRef = storage.refFromURL(image_url);
            await imageRef.delete();
            print("Deleted image from storage: $image_url");
          } catch (e) {
            print("Error deleting image from storage ($image_url): $e");
          }
        }
      }

      _markedForDeletionImages.clear();
      _markedForDeletionFiles.clear();
    } catch (e) {
      print("Error during _deleteSelectedMedia: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('미디어 파일 삭제 중 오류 발생: $e')),
      );
    } finally {
      setState(() {
        ing = false;
      });
    }
  }


  Future<void> downloadFile(String url, BuildContext context) async {
    Dio dio = Dio();
    String? directoryPath = await getSavedDirectory();

    if (directoryPath == null) {
      directoryPath = await selectFolder();
      if (directoryPath == null) {
        return;
      }
    }

    try {
      Uri uri = Uri.parse(url);
      String fileName = uri.pathSegments.last;
      if (fileName.length > 4) {
        fileName = fileName.substring(4);
      }
      await dio.download(url, "$directoryPath/$fileName");
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 다운로드 중 오류 발생: $e')),
      );
    }
  }

  void _openFile(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void _editPost(BuildContext context) {
    setState(() {
      _isEditMode = true;
    });
  }

  Future<void> _pickNewImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    setState(() {
      _newSelectedImages.addAll(images);
    });
  }

  Future<void> _pickNewFiles() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _newSelectedFiles.addAll(
          result.files.map((file) => XFile(file.path!)).toList(),
        );
      });
    }
  }

  void _savePost() async {
    setState(() {
      ing = true;
    });

    try {
      List<String> newImageUrls = [];
      List<String> newFileUrls = [];

      int filesizeSum = 0;
      for (var image in _newSelectedImages) {
        File imageFile = File(image.path);
        filesizeSum += await imageFile.length();
      }
      for (var file in _newSelectedFiles) {
        File theFile = File(file.path);
        filesizeSum += await theFile.length();
      }

      if (filesizeSum > 25 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('첨부 가능한 파일 용량은 최대 25MB입니다.')),
        );
        setState(() {
          ing = false;
        });
        return;
      }

      if (!kIsWeb) {
        for (var image in _newSelectedImages) {
          File imageFile = File(image.path);
          String image_url = await _uploadFileToStorage(imageFile, 'FourThirty');
          newImageUrls.add(image_url);
        }
      }

      if (!kIsWeb) {
        for (var file in _newSelectedFiles) {
          File fileToUpload = File(file.path);
          String file_url = await _uploadFileToStorage(fileToUpload, 'FourThirty');
          newFileUrls.add(file_url);
        }
      }

      List<String> titleArr = [];
      if (_titleController.text.isNotEmpty) {
        List<String> titleWordArr = _titleController.text.split(' ');
        for (String words in titleWordArr) {
          String word = '';
          for (String char in words.characters) {
            word = word + char;
            titleArr.add(word);
          }
        }
      }


      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.documentId)
          .update({
        'title': _titleController.text,
        'title_arr': titleArr,
        'description': _descriptionController.text,
        'image_url': List<String>.from(_post['image_url'])..addAll(newImageUrls),
        'file_url': List<String>.from(_post['file_url'])..addAll(newFileUrls),
      });

      var updatedPostSnapshot =
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.documentId)
          .get();
      setState(() {
        _isEditMode = false;
        _newSelectedImages.clear();
        _newSelectedFiles.clear();
        _post = updatedPostSnapshot.data() as Map<String, dynamic>;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물이 성공적으로 저장되었습니다.')),
      );

    } catch (e) {
      print("Error saving post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('게시물 저장 실패: $e')),
      );
    } finally {
      setState(() {
        ing = false;
      });
    }
  }


  Future<String> _uploadFileToStorage(File file, String folder) async {
    String uuid = const Uuid().v4().substring(0, 4);
    String fileName = '$uuid${path.basename(file.path)}';
    Reference ref = storage.ref().child('$folder/$fileName');
    UploadTask uploadTask = ref.putFile(file);

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('이 게시물을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () {
                _deletePost();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePost() async {
    try {
      var commentsSnapshot =
      await FirebaseFirestore.instance
          .collection('comments')
          .where('post_id', isEqualTo: widget.documentId)
          .get();
      for (var doc in commentsSnapshot.docs) {
        _deleteComment(doc.id, doc['file_url']);
      }

      FirebaseStorage storage = FirebaseStorage.instance;
      List<dynamic> file_urls = _post['file_url'] ?? [];
      List<dynamic> image_urls = _post['image_url'] ?? [];

      for (var file_url in file_urls) {
        if (file_url != null && file_url.isNotEmpty) {
          try {
            var fileRef = storage.refFromURL(file_url);
            await fileRef.delete();
          } catch (e) {
            print("Error deleting Storage file ($file_url): $e");
          }
        }
      }

      for (var image_url in image_urls) {
        if (image_url != null && image_url.isNotEmpty) {
          try {
            var imageRef = storage.refFromURL(image_url);
            await imageRef.delete();
          } catch (e) {
            print("Error deleting Storage image ($image_url): $e");
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.documentId)
          .delete();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물이 성공적으로 삭제되었습니다.')),
      );
    } catch (e) {
      print("Error deleting post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('게시물 삭제 실패: $e')),
      );
    }
  }
}