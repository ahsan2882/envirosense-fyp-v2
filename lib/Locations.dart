import 'package:flutter/material.dart';
import 'package:envirosense/ValueNotifiers.dart';
import 'package:envirosense/functions.dart' as functions;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:envirosense/app_icon_icons.dart';
import 'package:envirosense/Maps.dart';
import 'package:envirosense/SettingPage.dart';
import 'package:envirosense/NodeScreen.dart';

final ValueNotifier<int> _devCount = ValueNotifier<int>(0);
int i = 0;
bool value = false;

class LocationPage extends StatefulWidget {
  final int devCount;
  const LocationPage({Key? key, required this.devCount}) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  @override
  void initState() {
    super.initState();
    _devCount.value = widget.devCount;
    _getVal();
  }
  @override
  void dispose() {
    super.dispose();
  }

  late List<dynamic> data;
  _getVal() async{
    final prefs = await SharedPreferences.getInstance();
    i = prefs.getInt('tbLinkIndex') ?? 0;
    value = prefs.getBool('demoServer') ?? true;
    location.value = [];
    longitude.value = [];
    latitude.value = [];
    for(int i = 0; i < _devCount.value; i++){
      await _getLocValues(i);
    }
  }
  Future<Map<String, dynamic>> _getLocValues(int index) async{
    String bearerToken = await functions.read('bearerToken.txt') ?? "h";
    String deviceId = await functions.read('devId${index+1}.txt') ?? "h";
    var url = Uri.parse('https://${tbLinks[i]}/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries?keys=latitude,longitude,location');
    var response = await http.get(
        url,
        headers: {
          'Content-Type':'application/json',
          'Accept':'application/json',
          'X-Authorization': bearerToken,
        }
    );
    var data = await json.decode(response.body);
    location.value = List.from(location.value)..add((data['location'][0]['value']).toString());
    longitude.value = List.from(longitude.value)..add((data['longitude'][0]['value']).toString());
    latitude.value = List.from(latitude.value)..add((data['latitude'][0]['value']).toString());
    return json.decode(response.body);
  }
  Future<Map<String,dynamic>> _getDeviceId () async{
    String bearerToken = await functions.read('bearerToken.txt') ?? "h";
    var url = Uri.parse('https://${tbLinks[i]}/api/tenant/devices?pageSize=10000&page=0');
    var responseDev = await http.get(
        url,
        headers: {
          'Content-Type':'application/json',
          'Accept':'application/json',
          'X-Authorization':bearerToken,
        }
    );
    data = await json.decode(responseDev.body)['data'];
    if(_devCount.value < data.length){
      for(int i = _devCount.value; i < data.length; i++){
        String devId = data[i]['id']['id'].toString();
        await functions.save('devId${i+1}.txt', devId);
      }
    }
    _devCount.value = data.length;
    await _getVal();
    return json.decode(responseDev.body);
  }
  _refresh() async{
    await _getDeviceId();
  }
  _goToNode(int index) async{
    String deviceId = await functions.read('devId${index+1}.txt') ?? "h";
    if(!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
        builder: (context) => LoadingState(devId: deviceId, index: index)
    ));
  }
  _goToMap() async{
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MapPage(latValue: 24.919, longValue: 67.065, zoom: 12.0 * MediaQuery.of(context).size.width / screenWidth)
        )
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EnviroSense',
          style: TextStyle(
              fontSize: 20 * MediaQuery.of(context).size.width / screenWidth,
              fontFamily: 'AstroSpace'
          ),
          textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
        ),
        leading: Icon(AppIcon.globe_2,
          color: Colors.blue,
          size: 35 * MediaQuery.of(context).size.width / screenWidth,
        ),
        actions: <Widget>[
          IconButton(icon: const Icon(
              Icons.settings,
              color: Colors.white
          ),
            onPressed: () async{
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Setting(val: value)
                  )
              );
            },
          )
        ],
      ),
      backgroundColor: Colors.grey[400],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints){
            return Center(
              child: RefreshIndicator(
                onRefresh: () async{
                  await _refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    constraints: constraints,
                    child: Padding(
                      padding: EdgeInsets.all(8 * MediaQuery.of(context).size.width / screenWidth),
                      child: Center(
                        child: ValueListenableBuilder(
                          valueListenable: location,
                          builder: (context, List items, _){
                            return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  if(items.length != _devCount.value)
                                    Padding(
                                      padding: EdgeInsets.only(left: 80 * MediaQuery.of(context).size.width / screenWidth, right: 80 * MediaQuery.of(context).size.width / screenWidth),
                                      // child: LinearProgressIndicator(
                                      //   minHeight: 6 * MediaQuery.of(context).size.width / screenWidth,
                                      //   value: items.length / _devCount.value,
                                      //
                                      // ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: <Widget>[
                                          SpinKitFadingGrid(
                                            size: 60.0 * MediaQuery.of(context).size.width / screenWidth,
                                            color: const Color(0xff00356a),
                                          ),
                                          SizedBox(
                                            width: 30 * MediaQuery.of(context).size.width / screenWidth,
                                            height: 30 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                          Text(
                                            'Fetching Available Locations',
                                            style: TextStyle(
                                                fontSize: 24 * MediaQuery.of(context).size.width / screenWidth,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[800]
                                            ),
                                            textAlign: TextAlign.center,
                                          )
                                        ],
                                      ),
                                    )
                                  else
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: items.map<Widget>(
                                              (item) => Card(
                                                child: Center(
                                                  child: ListTile(
                                                    leading: const Icon(Icons.location_on),
                                                    title: Text(
                                                      item,
                                                      style: TextStyle(
                                                          fontSize: 16 * MediaQuery.of(context).size.width / screenWidth
                                                      ),
                                                    ),
                                                    onTap: () async{
                                                      await _goToNode(items.indexOf(item));
                                                    },
                                                  ),
                                                ),
                                              )
                                      ).toList(),
                                    ),
                                  if(items.length == _devCount.value)
                                    Padding(
                                      padding: EdgeInsets.all(10 * MediaQuery.of(context).size.width / screenWidth),
                                      child: ElevatedButton(
                                          onPressed: () async{
                                            await _goToMap();
                                          },
                                          child: Text(
                                            "Maps",
                                            style: TextStyle(
                                                fontSize: 16 * MediaQuery.of(context).size.width / screenWidth
                                            ),
                                          )
                                      ),
                                    ),

                                ]
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LoadingState extends StatefulWidget {
  final String devId;
  final int index;
  const LoadingState({Key? key, required this.devId, required this.index}) : super(key: key);

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState> {
  @override
  void initState() {
    super.initState();
    _getVal();
  }
  @override
  void dispose() {
    super.dispose();
  }
  int lastAQI=0;
  int lastTemp=0;
  int lastHumid=0;
  int lastPressure=0;
  double lastPm25Con=0.0;
  double lastNo2Con=0.0;
  double lastCoCon=0.0;

  _getVal() async{
    await _getAllValues();
    if(!mounted) return;
    await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => Node(deviceId: widget.devId, index: widget.index, lastAqi: lastAQI, lastCo: lastCoCon, lastHum: lastHumid, lastNo2: lastNo2Con, lastPm: lastPm25Con, lastTem: lastTemp, lastPres: lastPressure)
        )
    );
  }
  _getAllValues() async{
    lastAQI = int.parse(await functions.read('lastAQI${widget.index}.txt') ?? "0");
    lastHumid = int.parse(await functions.read('lastHumid${widget.index}.txt') ?? "0");
    lastTemp = int.parse(await functions.read('lastTemp${widget.index}.txt') ?? "0");
    lastPressure = int.parse(await functions.read('lastPressure${widget.index}.txt') ?? "0");
    lastNo2Con = double.parse(await functions.read('lastNo2Con${widget.index}.txt') ?? "0.0");
    lastPm25Con = double.parse(await functions.read('lastPm25Con${widget.index}.txt') ?? "0.0");
    lastCoCon = double.parse(await functions.read('lastCoCon${widget.index}.txt') ?? "0.0");
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              strokeWidth: 5 * MediaQuery.of(context).size.width / screenWidth,
              backgroundColor: Colors.grey[300],
            ),
          )
      ),
    );
  }
}

