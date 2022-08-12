import 'package:flutter/material.dart';
import 'package:envirosense/ValueNotifiers.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:envirosense/functions.dart' as functions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:envirosense/Locations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

int i = 0;
int loginTries = 0;
bool demoVal = true;

final ValueNotifier<List> _users = ValueNotifier<List>([]);

class LoadingScreen extends StatefulWidget {
  final String title;
  const LoadingScreen({Key? key, required this.title}) : super(key: key);
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String username = "";
  String password = "";
  @override
  void initState() {
    super.initState();
    connectToFireBase();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void connectToFireBase() async {
    await FirebaseFirestore.instance
        .collection('users')
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        String username = doc['username'];
        String password = doc['password'];
        String serverType = doc['serverType'];
        _users.value = addUserToList(serverType, username, password);
      }
    });
    await _checkConnection();
  }

  List<Map<String, String>> addUserToList(serverType, username, password) {
    return List.from(_users.value)
      ..add({
        'serverType': serverType,
        'username': username,
        'password': password
      });
  }

  String bearerToken = "";

  late http.Response response;
  late List<dynamic> data;

  _login(String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    subtitle.value = "Connecting to server";
    var url = Uri.parse('https://${tbLinks[i]}/api/auth/login');
    var body = json.encode({"username": user, "password": pass});
    response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: body,
    );
    await prefs.setInt('logInResponse', response.statusCode);
    if (response.statusCode != 200) {
      i++;
      loginTries++;
      if (loginTries > 7) {
        subtitle.value = "Error Connecting to Server";
        _showPopup();
      }
    } else if (response.statusCode == 200) {
      loginTries = 0;
      await prefs.setInt('tbLinkIndex', i);
      String token = json.decode(response.body)['token'].toString();
      bearerToken = 'Bearer\$$token';
      await functions.save('bearerToken.txt', bearerToken);
      subtitle.value = "Connected to server";
    }
  }

  Future<Map<String, dynamic>> _getDeviceIds() async {
    final prefs = await SharedPreferences.getInstance();
    i = prefs.getInt('tbLinkIndex') ?? 0;
    var url = Uri.parse(
        'https://${tbLinks[i]}/api/tenant/devices?pageSize=10000&page=0');
    var response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Authorization': bearerToken,
    });
    data = await json.decode(response.body)['data'];
    for (int i = 0; i < data.length; i++) {
      String devId = data[i]['id']['id'].toString();
      await functions.save('devId${i + 1}.txt', devId);
    }
    return json.decode(response.body);
  }

  _checkConnection() async {
    final prefs = await SharedPreferences.getInstance();
    i = prefs.getInt('tbLinkIndex') ?? 0;
    demoVal = prefs.getBool('demoServer') ?? true;
    if (demoVal == true) {
      var credentials =
          _users.value.singleWhere((user) => user['serverType'] == 'cloud');
      username = credentials['username'];
      password = credentials['password'];
      i = 0;
    } else {
      var credentials =
          _users.value.singleWhere((user) => user['serverType'] == 'local');
      username = credentials['username'];
      password = credentials['password'];
      i = 1;
    }
    // await prefs.setInt('tbLinkIndex', 0);
    bool status = await InternetConnectionChecker().hasConnection;
    if (!status) {
      subtitle.value = "NO INTERNET CONNECTION";
      await Future.delayed(const Duration(seconds: 1));
      await _showPopup();
    } else {
      // await Future.delayed(Duration(seconds: 1));
      // subtitle.value = "CONNECTED";
      await Future.delayed(const Duration(seconds: 1));
      title.value = widget.title;
      await _login(username, password);
      int? statusCode = prefs.getInt('logInResponse');
      while (statusCode != 200) {
        statusCode = prefs.getInt('logInResponse');
        if (i > 5) {
          i = 0;
          var credentials =
              _users.value.singleWhere((user) => user['serverType'] == 'cloud');
          username = credentials['username'];
          password = credentials['password'];
          await prefs.setBool('demoServer', true);
        }
        await _login(username, password);
      }
      await _getDeviceIds();
      await _route();
    }
  }

  _route() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => LocationPage(devCount: data.length)),
    );
  }

  _showPopup() async {
    String title = "You are disconnected from the internet. ";
    String subtitle = "Please check your internet connection";
    await _showDialog(title, subtitle, context);
  }

  _showDialog(String title, String subtitle, BuildContext context) async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Text(
                title,
                style: TextStyle(
                  fontSize:
                      18 * MediaQuery.of(context).size.width / screenWidth,
                ),
              ),
              content: Text(
                subtitle,
                style: TextStyle(
                  fontSize:
                      18 * MediaQuery.of(context).size.width / screenWidth,
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    SystemNavigator.pop(animated: true);
                  },
                  child: Text(
                    "Close Application",
                    style: TextStyle(
                      fontSize:
                          18 * MediaQuery.of(context).size.width / screenWidth,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _checkConnection();
                  },
                  child: Text(
                    "Retry",
                    style: TextStyle(
                      fontSize:
                          18 * MediaQuery.of(context).size.width / screenWidth,
                    ),
                  ),
                )
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff00356a),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 10),
              // Image(
              //   image: AssetImage('assets/logos/EnvLogo.png'),
              // ),
              Text(
                "ENVIROSENSE",
                style: TextStyle(
                  fontFamily: 'AstroSpace',
                  fontSize:
                      40 * MediaQuery.of(context).size.width / screenWidth,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing:
                      2.5 * MediaQuery.of(context).size.width / screenWidth,
                ),
              ),
              const Spacer(flex: 3),
              SpinKitThreeBounce(
                color: Colors.green,
                size: 35.0 * MediaQuery.of(context).size.width / screenWidth,
              ),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: subtitle,
                builder: (context, String subtitle, _) {
                  return Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          22 * MediaQuery.of(context).size.width / screenWidth,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const Spacer(flex: 10),
            ],
          ),
        ),
      ),
    );
  }
}
