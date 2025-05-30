import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
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
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart' as svg;

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String documentId;

  const PostDetailPage(
      {super.key, required this.post, required this.documentId});

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
  List<html.File> _newSelectedImagesWeb = [];
  List<html.File> _newSelectedFilesWeb = [];
  List<String> _markedForDeletionImages = [];
  List<String> _markedForDeletionFiles = [];
  String? _attachedFileUrl;
  bool ing = false;
  bool isLoading = false;
  FirebaseStorage storage =
      FirebaseStorage.instanceFor(bucket: 'gs://beolgyooffice.appspot.com');

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _titleController = TextEditingController(text: _post['title']);
    _relatedWorkController = TextEditingController(text: _post['relatedWork']);
    _descriptionController = TextEditingController(text: _post['description']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _relatedWorkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
    if (_isEditMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('게시물 수정'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // _isEditMode를 false로 설정하고 이전 페이지로 돌아갑니다.
              setState(() {
                _post = widget.post;
                _titleController = TextEditingController(text: _post['title']);
                _relatedWorkController =
                    TextEditingController(text: _post['relatedWork']);
                _descriptionController =
                    TextEditingController(text: _post['description']);
                _newSelectedImages = [];
                _newSelectedFiles = [];
                _newSelectedImagesWeb = [];
                _newSelectedFilesWeb = [];
                _markedForDeletionImages = [];
                _markedForDeletionFiles = [];

                _isEditMode = false;
              });
              // Navigator.pop(context);
            },
          ),
          actions: [
            if (ing == true)
              CircularProgressIndicator()
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
            // 현재 포커스를 가진 위젯을 해제하여 키보드를 숨깁니다.
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
                  decoration: const InputDecoration(labelText: '설명'),
                  maxLines: null,
                  style: TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickNewImages,
                  child: const Text('이미지 첨부'),
                ),
                const SizedBox(height: 20),
                Wrap(children: [
                  // Existing images that are not marked for deletion
                  ..._post['imageUrl']
                      .where((imageUrl) =>
                          !_markedForDeletionImages.contains(imageUrl))
                      .map<Widget>((imageUrl) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.network(imageUrl),
                        //Text(imageUrl),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          // Change button color to red
                          onPressed: () {
                            setState(() {
                              _markedForDeletionImages.add(imageUrl);
                              //_post['imageUrl'].remove(imageUrl);
                            });
                          },
                        ),
                      ],
                    );
                  }).toList(),
                ]),
                //웹 플랫폼에서 추가하려는 이미지
                if (kIsWeb) // 플랫폼이 웹인 경우
                  ..._newSelectedImagesWeb.map((file) {
                    return FutureBuilder<Uint8List>(
                      future: _readFileBytes(file),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Image.memory(snapshot.data!),
                              // 이미지 파일의 바이트 데이터로 이미지 표시
                              IconButton(
                                icon: Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => setState(
                                    () => _newSelectedImagesWeb.remove(file)),
                              ),
                            ],
                          );
                        } else {
                          return CircularProgressIndicator(); // 이미지 로딩 중
                        }
                      },
                    );
                  }),
                // 비웹 플랫폼에서 새로 선택한 이미지 표시
                if (!kIsWeb)
                  ..._newSelectedImages.map<Widget>((image) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(File(image.path)),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          // Change button color to red
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
                ...(_post['fileUrl'] as List<dynamic>).map((fileUrl) {
                  if (!_markedForDeletionFiles.contains(fileUrl)) {
                    return ListTile(
                      title: Text(Uri.parse(fileUrl).pathSegments.last),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => setState(
                            () => _markedForDeletionFiles.add(fileUrl)),
                      ),
                    );
                  } else {
                    return Text('');
                  }
                }),
                // 웹에서 새로 선택한 파일을 표시
                if (kIsWeb)
                  ...(_newSelectedFilesWeb).map((file) {
                    return ListTile(
                      title: Text(file.name), // html.File의 name 속성 사용
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () =>
                            setState(() => _newSelectedFilesWeb.remove(file)),
                      ),
                    );
                  }),
                // 비웹 플랫폼에서 새로 선택한 파일을 표시
                if (!kIsWeb)
                  ...(_newSelectedFiles as List<dynamic>).map((fileUrl) {
                    if (_newSelectedFiles.contains(fileUrl)) {
                      return ListTile(
                        title: Text('new file'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () =>
                              setState(() => _newSelectedFiles.remove(fileUrl)),
                        ),
                      );
                    } else {
                      return Text('');
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
          // 현재 포커스를 가진 위젯을 해제하여 키보드를 숨깁니다.
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _post['title'] ?? '제목 없음', maxLines: 2, // 최대 2줄까지만 표시
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dynamicFontSize),
            ),
            actions: isCurrentUser
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_post['relatedWork'] != '')
                  Text('관련 업무: ${_post['relatedWork'] ?? '없음'}'),
                const SizedBox(height: 10),
                SelectableLinkify(
                  contextMenuBuilder: (context, editableTextState) {
                    final List<ContextMenuButtonItem> buttonItems =
                        editableTextState.contextMenuButtonItems;
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: buttonItems,
                    );
                  },
                  onOpen: (link) async => await _launchURL(Uri.parse(link.url)),
                  text: '설명: ${_post['description'] ?? '없음'}',
                  style: TextStyle(
                      color: Colors.black, // 일반 텍스트 색상
                      fontSize: 17),
                  linkStyle: TextStyle(
                    color: Colors.blue, // 링크 색상
                    decoration: TextDecoration.underline, // 밑줄 추가
                    decorationColor: Colors.blue,
                    // backgroundColor: Colors.blue.withOpacity(0.2),
                  ),
                ),
                //Text('설명: ${_post['description'] ?? '없음'}'),
                const SizedBox(height: 20),
                _buildImageSection(),
                _buildFileSection(),
                Divider(
                  height: 1,
                  thickness: 3,
                  color: Color(0xffcccccc),
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

  Future<Uint8List> _readFileBytes(html.File file) async {
    try {
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;
      final dataUrl = reader.result as String;
      final encodedString = dataUrl.split(',')[1]; // Base64로 인코딩된 데이터만 추출
      return base64.decode(encodedString); // Base64 문자열을 Uint8List로 변환
    } catch (e) {
      print("Error reading file bytes: $e");
      rethrow;
    }
  }




  RegExp regExp = RegExp(r'^[\d-]+$');

  _launchURL(Uri url) async {
    if (url.toString().startsWith('http')) {
      if (await canLaunchUrl(url)) {
        launchUrl(url);
      } else {
        // ignore: avoid_print
        print("Can't launch $url");
      }
    } else if (regExp.hasMatch(url.toString())) {
      final telUrl = Uri.parse(url.toString());
      launchUrl(telUrl);
    } else {
      print('Could not launch $url');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('링크를 열 수 없습니다: $url')));
    }
  }

  Widget _buildImageSection() {
    if (_post['imageUrl'] != null &&
        (_post['imageUrl'] as List<dynamic>).isNotEmpty) {
      List<dynamic> imageUrls = _post['imageUrl'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이미지', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...List.generate(imageUrls.length, (index) {
            String imageUrl = imageUrls[index];
            return Row(
              children: [
                InkWell(
                  onTap: () => _openImage(imageUrl),
                  child: const Text('이미지 보기',
                      style: TextStyle(color: Colors.blue)),
                ),
                const SizedBox(width: 20),
                InkWell(
                  onTap: () => _showDownloadDialog(context, imageUrl, '이미지'),
                  child: const Text('이미지 다운로드',
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          }),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildFileSection() {
    if (_post['fileUrl'] != null &&
        (_post['fileUrl'] as List<dynamic>).isNotEmpty) {
      List<dynamic> fileUrls = _post['fileUrl'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('첨부파일', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...List.generate(fileUrls.length, (index) {
            String fileUrl = fileUrls[index];
            return Row(
              children: [
                InkWell(
                  onTap: () => _openFile(fileUrl),
                  child: SizedBox(
                    width: 0.5 * MediaQuery.of(context).size.width,
                    child: Text(
                      Uri.parse(fileUrl).pathSegments.last,
                      style: TextStyle(color: Colors.blue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                InkWell(
                  onTap: () => _showDownloadDialog(context, fileUrl, '파일'),
                  child: const Text('파일 다운로드',
                      style: TextStyle(color: Colors.blue)),
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
      stream: FirebaseFirestore.instance
          .collection('comments')
          .where('post_id', isEqualTo: widget.documentId)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        } else {
          return Column(
            children: snapshot.data!.docs.map((document) {
              bool isCommentOwner = currentUser?.uid == document['made_by'];
              return ListTile(
                leading: Text(document['user_name'] + ':'),
                title: SelectableText(
                  document['title'],
                  toolbarOptions: ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
                subtitle: document['file_url'] != ''
                    ? InkWell(
                        child: Text('파일 다운로드'),
                        onTap: () => _showDownloadDialog(
                            context, document['file_url'], '파일'),
                      )
                    : null,
                trailing: isCommentOwner
                    ? IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _confirmDeleteComment(
                            context, document.id, document['file_url']),
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
      builder: (context) => AlertDialog(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$fileName 다운로드 완료')),
                );
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('다운로드 에러: $e')),
                );
                print(e);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(
      BuildContext context, String commentId, String? fileUrl) {
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
                _deleteComment(commentId, fileUrl);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteComment(String commentId, String? fileUrl) async {
    if (fileUrl != '' && fileUrl != null) {
      await FirebaseStorage.instance.refFromURL(fileUrl).delete();
    }
    await FirebaseFirestore.instance
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: '댓글 입력...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.attach_file),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _pickAndUploadFile();
            },
          ),
          if (isLoading == true)
            CircularProgressIndicator()
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitComment,
              //submitCommentWithAttachments(_commentController.text, []);
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    if (kIsWeb) {
      // 웹 환경에서 파일 선택
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.multiple = false; // 여러 파일 선택 비활성화
      uploadInput.click();

      uploadInput.onChange.listen((event) {
        final file = uploadInput.files!.first;
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((event) async {
          // 파일 업로드 로직을 여기에 구현합니다.
          // 예: _uploadFileToWeb(file);
          setState(() {
            isLoading = true;
          });
          String fileUrl = await _uploadFileToWeb(file, 'TeamToDo');
          _submitAttachment(fileUrl);
          setState(() {
            isLoading = false;
          });
        });
      });
    } else {
      // 모바일/데스크톱 환경에서 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null) {
        File file = File(result.files.single.path!);
        setState(() {
          isLoading = true;
        });
        String fileUrl = await _uploadFileToStorage(file, 'TeamToDo');
        _submitAttachment(fileUrl);
        setState(() {
          isLoading = false;
        });
      } else {
        // 사용자가 파일 선택을 취소한 경우
        setState(() {
          isLoading = false; // 로딩 상태를 해제
        });
      }
    }
  }

  // Future<void> _pickAndUploadFile() async {
  //   FilePickerResult? result = await FilePicker.platform.pickFiles(
  //     type: FileType.any,
  //     allowMultiple: false,
  //   );
  //   if (result != null) {
  //     _uploadFileToStorage2(result);
  //   } else {
  //     // 사용자가 파일 선택을 취소한 경우
  //     setState(() {
  //       isLoading = false; // 로딩 상태를 해제
  //     });
  //   }
  // }
  //
  // Future<void> _uploadFileToStorage2(dynamic result) async {
  //   if (kIsWeb) {
  //     // 웹 플랫폼일 경우의 처리
  //     html.File file = result as html.File;
  //     final fileSize = file.size;
  //
  //     if (fileSize > 25 * 1024 * 1024) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text('첨부 가능한 파일 용량은 최대 25MB입니다.')));
  //       return;
  //     }
  //
  //     String uuid = Uuid().v4().substring(0, 4); // 표준 UUID 생성, 처음 4자리 사용
  //     String fileName = '$uuid${path.basename(file.name)}';
  //     Reference ref = FirebaseStorage.instance.ref().child('TeamToDo/$fileName');
  //
  //     final reader = html.FileReader();
  //     reader.readAsDataUrl(file); // 파일을 Data URL로 읽습니다.
  //     await reader.onLoad.first;
  //
  //     final bytes = reader.result as String;
  //     final blob = html.Blob([bytes]);
  //     UploadTask uploadTask = ref.putBlob(blob);
  //     TaskSnapshot snapshot = await uploadTask;
  //     String fileUrl = await snapshot.ref.getDownloadURL();
  //     _submitAttachment(fileUrl);
  //   } else {
  //     // 비웹 플랫폼일 경우의 처리
  //     File file = File(result.files.single.path!);
  //     int fileSize = await file.length();
  //     if (fileSize > 25 * 1024 * 1024) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text('첨부 가능한 파일 용량은 최대 25MB입니다.')));
  //       return;
  //     } else {
  //       String uuid = Uuid().v4().substring(0, 4); // 표준 UUID 생성, 처음 4자리 사용
  //       String fileName = '$uuid${path.basename(file.path)}';
  //       Reference ref = FirebaseStorage.instance.ref().child('TeamToDo/$fileName');
  //       UploadTask uploadTask = ref.putFile(file);
  //       TaskSnapshot snapshot = await uploadTask;
  //       String fileUrl = await snapshot.ref.getDownloadURL();
  //       _submitAttachment(fileUrl);
  //     }
  //   }
  //   setState(() {
  //     isLoading = false; // 로딩 상태를 해제
  //   });
  // }

  void _submitAttachment(String fileUrl) async {
    setState(() {
      _attachedFileUrl = fileUrl; // 파일 URL 저장
    });
  }

  String userName = '';

  Future<void> _getUsersNames(String? userUid) async {
    var userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userUid).get();
    userName = userDoc.data()?['user_name'] ?? 'Unknown';
  }

  void _submitComment() async {
    if (_commentController.text.isNotEmpty) {
      await _getUsersNames(currentUser?.uid);

      Map<String, dynamic> commentData = {
        'post_id': widget.documentId,
        'title': _commentController.text,
        'createdAt': DateTime.now(),
        'made_by': currentUser?.uid,
        'user_name': userName,
        'file_url': ''
      };

      if (_attachedFileUrl != null) {
        commentData['file_url'] = _attachedFileUrl; // 파일 URL 추가
      }

      await FirebaseFirestore.instance.collection('comments').add(commentData);
      _commentController.clear();
      setState(() {
        _attachedFileUrl = null; // 첨부 파일 URL 초기화
      });
    }
  }

  void _openImage(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

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

  void _deleteSelectedMedia() {
    setState(() {
      _post['imageUrl'] = (_post['imageUrl'] as List<dynamic>)
          .where((url) => !_markedForDeletionImages.contains(url))
          .toList();
      _post['fileUrl'] = (_post['fileUrl'] as List<dynamic>)
          .where((url) => !_markedForDeletionFiles.contains(url))
          .toList();
      for (var fileUrl in _markedForDeletionFiles) {
        _post['fileUrl'].remove(fileUrl);
        var fileRef = storage.refFromURL(fileUrl);

        fileRef.delete();
            }
      for (var imageUrl in _markedForDeletionImages) {
        _post['imageUrl'].remove(imageUrl);
        var imageRef = storage.refFromURL(imageUrl);
        imageRef.delete();
            }
      _markedForDeletionImages.clear();
      _markedForDeletionFiles.clear();
    });
  }

  Future<void> downloadFile(String url, BuildContext context) async {
    if (kIsWeb) {
      // 웹 플랫폼일 경우
      html.AnchorElement anchorElement = html.AnchorElement(href: url)
        ..setAttribute("download", "true")
        ..click();
    } else {
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
        // 파일명에서 앞 4글자를 삭제
        if (fileName.length > 4) {
          fileName = fileName.substring(4);
        }
        await dio.download(url, "$directoryPath/$fileName");
      } catch (e) {
        print(e);
      }
    }
  }

  void _openFile(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _editPost(BuildContext context) {
    setState(() {
      _isEditMode = true; // 수정 모드로 전환
    });
  }

  // Add methods for picking new files and images
  Future<void> _pickNewImages() async {
    if (kIsWeb) {
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement()
        ..accept = 'image/*';
      uploadInput.multiple = true;
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files != null) {
          setState(() {
            _newSelectedImagesWeb.addAll(files);
          });
        }
      });
    } else {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      setState(() {
        _newSelectedImages.addAll(images);
      });
    }
  }

  Future<void> _pickNewFiles() async {
    if (kIsWeb) {
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.multiple = true;
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files != null) {
          setState(() {
            _newSelectedFilesWeb.addAll(files);
          });
        }
      });
    } else {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        setState(() {
          _newSelectedFiles
              .addAll(result.files.map((file) => XFile(file.path!)).toList());
        });
      }
    }
  }

// Modify the _savePost method
  void _savePost() async {
    try {
      // 이미지 및 파일 URL 목록을 저장할 리스트
      List<String> newImageUrls = [];
      List<String> newFileUrls = [];
      bool overLoad = false;
      int filesizeSum = 0;
      for (var image in _newSelectedImages) {
        File imageFile = File(image.path);
        int fileSize = await imageFile.length();
        filesizeSum = filesizeSum + fileSize;
      }
      for (var file in _newSelectedFiles) {
        File theFile = File(file.path);
        int fileSize = await theFile.length();
        filesizeSum = filesizeSum + fileSize;
      }
      if (filesizeSum > 25 * 1024 * 1024) {
        overLoad = true;
      }

      //용량합이 25메가 넘으면 안됨.
      if (overLoad) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('첨부 가능한 파일 용량은 최대 25MB입니다.')));
        overLoad = false;
        ing = false;
      } else {
        // 새로 선택된 이미지를 Firebase Storage에 업로드하고 URL을 저장
        if (!kIsWeb) {
          // 기존 모바일/데스크톱 환경에서의 업로드 로직
          for (var image in _newSelectedImages) {
            File imageFile = File(image.path);
            String imageUrl = await _uploadFileToStorage(imageFile, 'TeamToDo');
            newImageUrls.add(imageUrl);
          }
        } else {
          // 웹 환경에서의 업로드 로직
          for (var image in _newSelectedImagesWeb) {
            String imageUrl = await _uploadFileToWeb(image, 'TeamToDo');
            newImageUrls.add(imageUrl);
          }
        }

        // 새로 선택된 파일을 Firebase Storage에 업로드하고 URL을 저장
        if (!kIsWeb) {
          // 기존 모바일/데스크톱 환경에서의 업로드 로직
          for (var file in _newSelectedFiles) {
            File fileToUpload = File(file.path);
            String fileUrl =
                await _uploadFileToStorage(fileToUpload, 'TeamToDo');
            newFileUrls.add(fileUrl);
          }
        } else {
          // 웹 환경에서의 업로드 로직
          for (var file in _newSelectedFilesWeb) {
            String fileUrl = await _uploadFileToWeb(file, 'TeamToDo');
            newFileUrls.add(fileUrl);
          }
        }
        List<String>? titleArr = [];
        List<String> titleWordArr = _titleController.text.split(' ');
        for (String words in titleWordArr) {
          String word = '';
          for (String char in words.characters) {
            word = word + char;
            titleArr.add(word);
          }
          word = '';
        }
        // Firestore 업데이트 로직
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.documentId)
            .update({
          'title': _titleController.text,
          'title_arr': titleArr,
          'description': _descriptionController.text,
          'imageUrl': _post['imageUrl']..addAll(newImageUrls),
          'fileUrl': _post['fileUrl']..addAll(newFileUrls),
        });

        // 새로운 데이터로 게시물 상태 업데이트
        var updatedPost = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.documentId)
            .get();
        setState(() {
          _isEditMode = false;
          _newSelectedImages.clear();
          _newSelectedFiles.clear();
          _post = updatedPost.data() as Map<String, dynamic>;
          ing = false;
        });
      }
    } catch (e) {
      // 오류 처리
      print("Error saving post: $e");
    }
  }

  // Add the _uploadFileToStorage method
  Future<String> _uploadFileToStorage(File file, String folder) async {
    String uuid = Uuid().v4().substring(0, 4); // 표준 UUID 생성
    String fileName = '$uuid${path.basename(file.path)}';
    Reference ref = storage.ref().child('$folder/$fileName');
    UploadTask uploadTask = ref.putFile(file);

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> _uploadFileToWeb(html.File file, String folder) async {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;
    final bytes = reader.result as String;
    final blob = html.Blob([bytes]);
    String uuid = Uuid().v4().substring(0, 4);
    String fileName = '$uuid${file.name}';
    Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName');

    UploadTask uploadTask = ref.putBlob(blob);
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return url;
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
    // 댓글 삭제
    var commentsSnapshot = await FirebaseFirestore.instance
        .collection('comments')
        .where('post_id', isEqualTo: widget.documentId)
        .get();
    for (var doc in commentsSnapshot.docs) {
      _deleteComment(doc.id, doc['file_url']);
    }

    // Firebase Storage에서 파일 및 이미지 삭제
    FirebaseStorage storage = FirebaseStorage.instance;
    List<dynamic> fileUrls = _post['fileUrl'] ?? [];
    List<dynamic> imageUrls = _post['imageUrl'] ?? [];

    for (var fileUrl in fileUrls) {
      if (fileUrl != null) {
        var fileRef = storage.refFromURL(fileUrl);
        await fileRef.delete();
      }
    }

    for (var imageUrl in imageUrls) {
      if (imageUrl != null) {
        var imageRef = storage.refFromURL(imageUrl);
        await imageRef.delete();
      }
    }

    // 포스트 삭제
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.documentId)
        .delete();
    Navigator.of(context).pop(); // 현재 페이지 닫기
  }
}
