import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class CreatePostPage extends StatefulWidget {
  final String? related;

  const CreatePostPage({super.key, this.related});

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<XFile> _selectedFiles = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String userGroupId = '';
  String relatedTaskName = '';
  bool isLoading = false;
  FirebaseStorage storage =
      FirebaseStorage.instanceFor(bucket: 'gs://four-thirty.firebasestorage.app');

  @override
  void initState() {
    super.initState();
    _fetchUserGroupId();
    _fetchRelatedTaskName();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 포스트 작성'),
        actions: <Widget>[
          if (isLoading == true)
            const CircularProgressIndicator()
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                _savePost();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImages,
              child: const Text('이미지 첨부'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickFiles,
              child: const Text('파일 첨부'),
            ),
            // Display selected image and file
            for (var image in _selectedImages)
              Container(
                width: 0.4 * MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(5),
                child: SizedBox(
                  width: 0.4 * MediaQuery.of(context).size.width,
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object exception,
                        StackTrace? stackTrace) {
                      // 이미지 로딩 중 오류가 발생했을 때 대체할 위젯을 반환합니다.
                      return Image.asset(
                        'assets/noimage.png', // 기본 이미지 파일 경로
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
            for (var file in _selectedFiles)
              Text('File: ${path.basename(file.path)}'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    setState(() => _selectedImages.addAll(images));
  }

  Future<void> _pickFiles() async {
    final FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _selectedFiles
            .addAll(result.files.map((file) => XFile(file.path!)).toList());
      });
    }
  }

  Future<void> _savePost() async {
    bool overLoad = false;
    int filesizeSum = 0;
    for (var image in _selectedImages) {
      File imageFile = File(image.path);
      int fileSize = await imageFile.length();
      filesizeSum = filesizeSum + fileSize;
    }
    for (var file in _selectedFiles) {
      File theFile = File(file.path);
      int fileSize = await theFile.length();
      filesizeSum = filesizeSum + fileSize;
    }
    if (filesizeSum > 25 * 1024 * 1024) {
      overLoad = true;
    }
    if (_titleController.text == '') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('포스트 제목은 필수입니다.')));
      isLoading = false;
    } else if (overLoad) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('첨부 가능한 파일 용량은 최대 25MB입니다.')));
      overLoad = false;
      isLoading = false;
    } else {
      try {
        List<String> image_urls = [];
        List<String> file_urls = [];

        // 이미지 업로드
        for (var image in _selectedImages) {
          File imageFile = File(image.path);
          String image_url = await _uploadFileToStorage(imageFile, 'FourThirty');
          image_urls.add(image_url);
        }

        // 파일 업로드
        for (var file in _selectedFiles) {
          File fileToUpload = File(file.path);
          String file_url = await _uploadFileToStorage(fileToUpload, 'FourThirty');
          file_urls.add(file_url);
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

        // Firestore에 게시물 정보 저장
        await FirebaseFirestore.instance.collection('posts').add({
          'title': _titleController.text,
          'title_arr': titleArr,
          'related_work': relatedTaskName,
          'related_task_id': widget.related,
          'description': _descriptionController.text,
          'image_url': image_urls,
          'file_url': file_urls,
          'created_at': DateTime.now(),
          'group_id': userGroupId, // 현재 사용자의 그룹 ID 추가
          'made_by': currentUser?.uid,
          // 여기에 필요한 추가 필드를 추가합니다.
        });

        // 저장 후 이전 화면으로 이동
        Navigator.pop(context);
        isLoading = false;
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('게시물 저장 중 오류가 발생했습니다: $e')));
        isLoading = false;
      }
    }
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

  void _fetchRelatedTaskName() async {
    if (widget.related != null) {
      var taskDoc =
          await firestore.collection('tasks').doc(widget.related).get();
      if (taskDoc.exists) {
        setState(() {
          relatedTaskName = taskDoc.data()!['task_name'];
        });
      }
    }
  }

  Future<String> _uploadFileToStorage(File file, String folder) async {
    String uuid = const Uuid().v4().substring(0, 4); // 표준 UUID 생성
    String fileName = '$uuid${path.basename(file.path)}';
    Reference ref = storage.ref().child('$folder/$fileName');
    UploadTask uploadTask = ref.putFile(file);

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
