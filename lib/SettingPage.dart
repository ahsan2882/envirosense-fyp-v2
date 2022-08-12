import 'package:flutter/material.dart';
import 'package:sliding_switch/sliding_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/services.dart';
import 'package:envirosense/main.dart';
import 'package:envirosense/ValueNotifiers.dart';

class Setting extends StatefulWidget {
  final bool val;
  const Setting({Key? key, required this.val}) : super(key: key);

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _showPopup() async {
    String title = "This requires restarting the app. ";
    await _showDialog(title, context);
  }

  _showDialog(String title, BuildContext context) async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Text(title),
              actions: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    RestartWidget.restartApp(context);
                  },
                  child: const Text("Restart Application"),
                )
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Center(
        child: SlidingSwitch(
          onChanged: (bool value) async {
            final prefs = await SharedPreferences.getInstance();
            if (value) {
              await prefs.setBool('demoServer', true);
            } else {
              await prefs.setBool('demoServer', false);
            }
            _showPopup();
          },
          value: widget.val,
          textOn: "Cloud Server",
          textOff: "StandAlone Server",
          width: 300 * MediaQuery.of(context).size.width / screenWidth,
          height: 65 * MediaQuery.of(context).size.width / screenWidth,
          onTap: () async => {},
          onSwipe: () async => {},
          onDoubleTap: () async => {},
        ),
      ),
    );
  }
}
