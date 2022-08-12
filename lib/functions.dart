library envirosense_fyp.functions;

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> get _localPath async{
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

save(String filename, String data) async{
  final path = await _localPath;
  final file = File('$path/$filename');
  return file.writeAsString(data);
}

read(String filename) async{
  try{
    final path = await _localPath;
    final file = File('$path/$filename');
    String data = await file.readAsString();
    return data;
  } catch(e){
    return null;
  }
}