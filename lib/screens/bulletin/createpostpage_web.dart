import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:js_interop';

class CreatePostPage extends StatefulWidget {
  final String? related;

  const CreatePostPage({super.key, this.related});

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<html.File> _newSelectedImagesWeb = [];
  final List<html.File> _newSelectedFilesWeb = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String userGroupId = '';
  String relatedTaskName = '';
  bool isLoading = false;
  FirebaseStorage storage =
      FirebaseStorage.instanceFor(bucket: 'gs://beolgyooffice.appspot.com');

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
              decoration: const InputDecoration(labelText: '설명'),
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
            ..._newSelectedImagesWeb.map((file) {
              return FutureBuilder<Uint8List>(
                future: _readFileBytes(file),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    return Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        SizedBox(
                            width: 0.4 * MediaQuery.of(context).size.width,
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (BuildContext context,
                                  Object exception, StackTrace? stackTrace) {
                                return Image.asset(
                                  'assets/noimage.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            )),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => setState(
                              () => _newSelectedImagesWeb.remove(file)),
                        ),
                      ],
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              );
            }),
            ...(_newSelectedFilesWeb).map((file) {
              return ListTile(
                title: Text(file.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      setState(() => _newSelectedFilesWeb.remove(file)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _readFileBytes(html.File file) async {
      final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.readAsDataURL(file);
    reader.addEventListener('load', (event) {
      final dataUrl = reader.result as String;
      final encodedString = dataUrl.split(',')[1];
      completer.complete(base64.decode(encodedString));
    } as html.EventListener);
    return completer.future;
  }

  Future<void> _pickImages() async {
    final uploadInput = html.HTMLInputElement();
    uploadInput.type = 'file';
    uploadInput.accept = 'image/*';
    uploadInput.multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null) {
        setState(() {
          _newSelectedImagesWeb.addAll([
            for (var i = 0; i < files.length; i++) files.item(i) as html.File
          ]);
        });
      }
    });
  }

  Future<void> _pickFiles() async {
    final uploadInput = html.HTMLInputElement();
    uploadInput.type = 'file';
    uploadInput.multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null) {
        setState(() {
          _newSelectedFilesWeb.addAll([
            for (var i = 0; i < files.length; i++) files.item(i) as html.File
          ]);
        });
      }
    });
  }

  Future<void> _savePost() async {
    if (_titleController.text == '') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('포스트 제목은 필수입니다.')));
      isLoading = false;
    } else {
      try {
        List<String> imageUrls = [];
        List<String> fileUrls = [];

        for (var image in _newSelectedImagesWeb) {
          String imageUrl = await _uploadFileToWeb(image, 'TeamToDo');
          if (imageUrl != '') {
            imageUrls.add(imageUrl);
          }
        }

        for (var file in _newSelectedFilesWeb) {
          String fileUrl = await _uploadFileToWeb(file, 'TeamToDo');
          if (fileUrl != '') {
            fileUrls.add(fileUrl);
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

        await FirebaseFirestore.instance.collection('posts').add({
          'title': _titleController.text,
          'title_arr': titleArr,
          'related_work': relatedTaskName,
          'related_task_id': widget.related,
          'description': _descriptionController.text,
          'image_url': imageUrls,
          'file_url': fileUrls,
          'created_at': DateTime.now(),
          'group_id': userGroupId,
          'made_by': currentUser?.uid,
        });

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

  Future<String> _uploadFileToWeb(html.File file, String folder) async {
    try {
      final String uuid = const Uuid().v4().substring(0, 4);
      final String fileName = '$uuid${file.name}';
      final blob = html.Blob([file].toJS);
      final ref = FirebaseStorage.instance.ref().child('$folder/$fileName');

      final uploadTask = ref.putBlob(blob);
      await uploadTask;

      final url = await ref.getDownloadURL();
      print('File uploaded successfully. URL: $url');
      return url;
    } catch (e) {
      print('Error uploading file: $e');
      return '';
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
}
