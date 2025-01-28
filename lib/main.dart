import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:azure_blob_flutter/azure_blob_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String uploadStatus = 'No image selected';
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  String? uploadedImageUrl;
  
  // Azure Configuration
  static const String storageAccount = "YOUR_STORAGE_ACCOUNT_NAME";
  static const String containerName = "YOUR_CONTAINER_NAME";
  static const String sasToken = "YOUR_SAS_TOKEN";
  
  late final String blobUrl;
  late final AzureBlobFlutter azureBlobFlutter;

  @override
  void initState() {
    super.initState();
    blobUrl = "https://$storageAccount.blob.core.windows.net";
    try {
      azureBlobFlutter = AzureBlobFlutter(
        blobUrl,
        "",
        containerName,
      );
      print('Azure Blob Storage initialized with:');
      print('Blob URL: $blobUrl');
      print('Container: $containerName');
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> uploadToBlob(String filePath, String fileName) async {
    try {
      // Read file as bytes
      final bytes = await File(filePath).readAsBytes();
      
      // Construct the full URL for the blob
      final blobName = Uri.encodeComponent(fileName);
      final uploadUrl = '$blobUrl/$containerName/$blobName$sasToken';
      final publicUrl = '$blobUrl/$containerName/$blobName$sasToken';
      
      print('Upload URL (partial): $blobUrl/$containerName/$blobName');

      // Create PUT request
      final request = http.Request('PUT', Uri.parse(uploadUrl));
      request.bodyBytes = bytes;
      request.headers.addAll({
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': 'image/jpeg',
      });

      // Send the request
      final response = await request.send();
      
      if (response.statusCode == 201) {
        setState(() {
          uploadStatus = 'Upload successful!\nFile: $fileName';
          uploadedImageUrl = publicUrl;
        });
      } else {
        final responseBody = await response.stream.bytesToString();
        setState(() {
          uploadStatus = 'Upload failed: ${response.statusCode}\n$responseBody';
          uploadedImageUrl = null;
        });
      }
    } catch (e) {
      setState(() {
        uploadStatus = 'Upload error: $e';
        uploadedImageUrl = null;
      });
      print('Upload error details: $e');
    }
  }

  void copyUrlToClipboard() {
    if (uploadedImageUrl != null) {
      Clipboard.setData(ClipboardData(text: uploadedImageUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> pickAndUploadImage() async {
    try {
      setState(() {
        uploadStatus = 'Selecting image...';
        uploadedImageUrl = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85
      );
      
      if (image == null) {
        setState(() {
          uploadStatus = 'No image selected';
        });
        return;
      }

      setState(() {
        _imageFile = image;
        uploadStatus = 'Processing image...';
      });

      print('Image path: ${image.path}');
      print('File exists: ${await File(image.path).exists()}');
      final fileSize = await File(image.path).length();
      print('File size: $fileSize bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'image_$timestamp.jpg';
      print('Generated filename: $fileName');

      await uploadToBlob(image.path, fileName);

    } catch (e) {
      print('Error: $e');
      setState(() {
        uploadStatus = 'Error: $e';
        uploadedImageUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Azure Blob Upload'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_imageFile != null) ...[
                  Image.file(
                    File(_imageFile!.path),
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 20),
                ],
                ElevatedButton(
                  onPressed: pickAndUploadImage,
                  child: const Text('Select and Upload Image'),
                ),
                const SizedBox(height: 20),
                Text(
                  uploadStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: uploadStatus.contains('successful') 
                        ? Colors.green 
                        : uploadStatus.contains('Error') || uploadStatus.contains('failed')
                            ? Colors.red 
                            : Colors.black,
                  ),
                ),
                if (uploadedImageUrl != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: copyUrlToClipboard,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy SAS URL'),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'URL: ${uploadedImageUrl!}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}