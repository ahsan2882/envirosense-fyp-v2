import 'package:flutter/material.dart';
import 'package:envirosense/app_icon_icons.dart';
import 'dart:async';
import 'package:envirosense/ValueNotifiers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:envirosense/functions.dart' as functions;
import 'package:syncfusion_flutter_gauges/gauges.dart';

int i = 0;

final ValueNotifier<bool> warningMinMax = ValueNotifier<bool>(true);
final ValueNotifier<bool> showStaleWarning = ValueNotifier<bool>(false);

double safeHeightAQI = (60 / 500) * 320;
double safeHeightNO = (2 / 10) * 320;
double safeHeightPM25 = (20 / 300) * 320;
double safeHeightCO = (9 / 100) * 320;

late Timer _timer;

late bool demoServer;

late DateTime currentTime;

class DataPage extends StatefulWidget {
  final String devId;
  final int devIndex;
  final int lastAqi;
  final int lastTem;
  final int lastHum;
  final int lastPres;
  final double lastPm;
  final double lastNo2;
  final double lastCo;
  const DataPage(
      {Key? key,
      required this.devId,
      required this.devIndex,
      required this.lastAqi,
      required this.lastTem,
      required this.lastHum,
      required this.lastPres,
      required this.lastPm,
      required this.lastNo2,
      required this.lastCo})
      : super(key: key);

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {

  double bpLo = 0.0;
  double bpHi = 0.0;
  int aqiLo = 0;
  int aqiHi = 0;
  @override
  void initState() {
    airQuality.value = widget.lastAqi;
    temperature.value = widget.lastTem;
    humidity.value = widget.lastHum;
    pressure.value = widget.lastPres;
    pm25Con.value = widget.lastPm;
    no2Con.value = widget.lastNo2;
    coCon.value = widget.lastCo;
    _getValues();
    startTimer();
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  startTimer(){
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _getValues();
    });
  }
  Future<void> _getValues() async{
    final prefs = await SharedPreferences.getInstance();
    airQuality.value = int.parse(await functions.read('lastAQI${widget.devIndex}.txt') ?? "0");
    humidity.value = int.parse(await functions.read('lastHumid${widget.devIndex}.txt') ?? "0");
    temperature.value = int.parse(await functions.read('lastTemp${widget.devIndex}.txt') ?? "0");
    pressure.value = int.parse(await functions.read('lastPressure${widget.devIndex}.txt') ?? "0");
    no2Con.value = double.parse(await functions.read('lastNo2Con${widget.devIndex}.txt') ?? "0.0");
    pm25Con.value = double.parse(await functions.read('lastPm25Con${widget.devIndex}.txt') ?? "0.0");
    coCon.value = double.parse(await functions.read('lastCoCon${widget.devIndex}.txt') ?? "0.0");
    demoServer = prefs.getBool('demoServer') ?? true;
    heightPM25.value = ((pm25Con.value) / maxPM25) *320;
    if(pm25Con.value <= safePM25){
      colorPM25.value = 0xff64e35f;
    }
    else if(pm25Con.value > safePM25 && pm25Con.value <= (maxPM25 * 0.3)){
      colorPM25.value = 0xffdfe35f;
    }
    else if(pm25Con.value > (maxPM25 * 0.3) && pm25Con.value <= maxPM25){
      colorPM25.value = 0xfff76060;
    }
    heightAQI.value = ((airQuality.value) / 500) * 320;
    if(airQuality.value == 0){
      healthStatus.value = "--";
      healthColor.value = 0xff03fc7f;
    }
    else if(airQuality.value <= 50 && airQuality.value > 0){
      healthColor.value = 0xff2cf61a;
      healthStatus.value = "Good";
    }
    else if(airQuality.value <= 100 && airQuality.value > 50){
      healthColor.value = 0xffedf93c;
      healthStatus.value = "Moderate";
    }
    else if(airQuality.value > 100 && airQuality.value <= 150){
      healthColor.value = 0xffff0303;
      healthStatus.value = "Unhealthy\nfor Sensitive Groups";
    }
    else if(airQuality.value > 150 && airQuality.value <= 200){
      healthColor.value = 0xffff9d00;
      healthStatus.value = "Unhealthy";
    }
    else if(airQuality.value > 200 && airQuality.value <= 300){
      healthColor.value = 0xffe730c4;
      healthStatus.value = "Very Unhealthy";
    }
    else if(airQuality.value > 300 && airQuality.value <= 500){
      healthColor.value = 0xffab0f3e;
      healthStatus.value = "Hazardous";
    }
    heightNO.value = ((no2Con.value) / maxNO) * 320;
    if(no2Con.value <= safeNO){
      colorNO2.value = 0xff64e35f;
    }
    else if(no2Con.value > safeNO && no2Con.value <= (maxNO * 0.6)){
      colorNO2.value = 0xffdfe35f;
    }
    else if(no2Con.value > (maxNO * 0.6) && no2Con.value <= maxNO){
      colorNO2.value = 0xfff76060;
    }
    heightCO.value = ((coCon.value) / maxCO) * 320;
    if(coCon.value <= safeCO){
      colorCO.value = 0xff64e35f;
    }
    else if(coCon.value > safeCO && coCon.value <= (maxCO * 0.4)){
      colorCO.value = 0xffdfe35f;
    }
    else if(coCon.value > (maxCO * 0.4) && coCon.value <= maxCO){
      colorCO.value = 0xfff76060;
    }
    i = prefs.getInt('tbLinkIndex') ?? 0;
    await _getAllValues();
  }
  Future<Map<String, dynamic>> _getAllValues() async{
    // int interval = 86400000; // 24 hour Average
    // int interval = 43200000; // 12 hour Average
    // int interval = 7200000;     // 2 hour Average
    int interval = 3600000;
    DateTime now = DateTime.now();
    // if(now.minute >= 30 && now.minute < 60){
    //   currentTime = DateTime(now.year, now.month, now.day, now.hour, 30, 0, 0, 0);
    // }
    // else if(now.minute >= 0 && now.minute < 30){
    //   currentTime = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);
    // }
    currentTime = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);
    // int startTs = currentTime.millisecondsSinceEpoch - (interval ~/ 2);
    // int endTs = currentTime.millisecondsSinceEpoch + (interval ~/ 2);
    int startTs = currentTime.millisecondsSinceEpoch - interval;
    int endTs = currentTime.millisecondsSinceEpoch;
    int startTs2 = currentTime.millisecondsSinceEpoch;
    int endTs2 = currentTime.millisecondsSinceEpoch + interval;
    String bearerToken = await functions.read('bearerToken.txt') ?? "h";
    // var response3 = await http.get(
    //   Uri.parse('https://${tbLinks[i]}/api/device/$_deviceId/credentials'),
    //   headers: {
    //     'Content-Type':'application/json',
    //     'Accept':'application/json',
    //     'X-Authorization': bearerToken,
    //   },
    // );
    // var data3 = await json.decode(response3.body);
    // String accessToken = data3['credentialsId'];
    var response2 = await http.get(
        Uri.parse('https://${tbLinks[i]}/api/plugins/telemetry/DEVICE/${widget.devId}/values/timeseries?agg=AVG&keys=pm25Con,coCon&startTs=$startTs&endTs=$endTs&interval=$interval'),
        headers: {
          'Content-Type':'application/json',
          'Accept':'application/json',
          'X-Authorization': bearerToken,
        }
    );
    var response4 = await http.get(
        Uri.parse('https://${tbLinks[i]}/api/plugins/telemetry/DEVICE/${widget.devId}/values/timeseries?agg=AVG&keys=pm25Con,coCon&startTs=$startTs2&endTs=$endTs2&interval=$interval'),
        headers: {
          'Content-Type':'application/json',
          'Accept':'application/json',
          'X-Authorization': bearerToken,
        }
    );
    var data2 = await json.decode(response2.body);
    var data4 = await json.decode(response4.body);

    // if (data2.isEmpty){
    //   if(data4.isEmpty){
    //     pm25Con.value = double.parse(await functions.read('lastPm25Con$_devIndex.txt') ?? "0.0");
    //     coCon.value = double.parse(await functions.read('lastCoCon$_devIndex.txt') ?? "0.0");
    //   } else{
    //     print('data4 = $data4');
    //     print("data4_pm25 = ${data4['pm25Con']}");
    //     print("data4_co = ${data4['coCon']}");
    //     if(data4['pm25Con'] == null){
    //       pm25Con.value = double.parse(await functions.read('lastPm25Con$_devIndex.txt') ?? "0.0");
    //     } else{
    //       pm25Con.value = double.parse(double.parse(data4['pm25Con'][0]['value']).toStringAsFixed(2));
    //     }
    //     if(data4['coCon'] == null){
    //       coCon.value = double.parse(await functions.read('lastCoCon$_devIndex.txt') ?? "0.0");
    //     } else{
    //       coCon.value = double.parse(double.parse(data4['coCon'][0]['value']).toStringAsFixed(2));
    //     }
    //   }
    // } else{
    //   print("data2_pm25 = ${data2['pm25Con']}");
    //   print("data2_co = ${data2['coCon']}");
    //   if(data2['pm25Con'] == null){
    //     pm25Con.value = double.parse(await functions.read('lastPm25Con$_devIndex.txt') ?? "0.0");
    //   } else{
    //     pm25Con.value = double.parse(double.parse(data2['pm25Con'][0]['value']).toStringAsFixed(2));
    //   }
    //   if(data2['coCon'] == null){
    //     coCon.value = double.parse(await functions.read('lastCoCon$_devIndex.txt') ?? "0.0");
    //   } else{
    //     coCon.value = double.parse(double.parse(data2['coCon'][0]['value']).toStringAsFixed(2));
    //   }
    // }
    // double conPm = double.parse(double.parse(data2['pm25Con'][0]['value']).toStringAsFixed(2));
    if(data2.isEmpty && data4.isEmpty){
      pm25Con.value = double.parse(await functions.read('lastPm25Con${widget.devIndex}.txt') ?? "0.0");
      coCon.value = double.parse(await functions.read('lastCoCon${widget.devIndex}.txt') ?? "0.0");
    }
    else if(data2.isEmpty && !data4.isEmpty){
      if(data4['pm25Con'] == null){
        pm25Con.value = double.parse(await functions.read('lastPm25Con${widget.devIndex}.txt') ?? "0.0");
        coCon.value = double.parse(double.parse(data4['coCon'][0]['value']).toStringAsFixed(2));
      }
      else if(data4['coCon'] == null){
        pm25Con.value = double.parse(double.parse(data4['pm25Con'][0]['value']).toStringAsFixed(2));
        coCon.value = double.parse(await functions.read('lastCoCon${widget.devIndex}.txt') ?? "0.0");
      }
      else {
        pm25Con.value = double.parse(double.parse(data4['pm25Con'][0]['value']).toStringAsFixed(2));
        coCon.value = double.parse(double.parse(data4['coCon'][0]['value']).toStringAsFixed(2));
      }
    }
    else {
      if(data2['pm25Con'] == null){
        pm25Con.value = double.parse(await functions.read('lastPm25Con${widget.devIndex}.txt') ?? "0.0");
        coCon.value = double.parse(double.parse(data2['coCon'][0]['value']).toStringAsFixed(2));
      }
      else if(data2['coCon'] == null){
        coCon.value = double.parse(await functions.read('lastCoCon${widget.devIndex}.txt') ?? "0.0");
        pm25Con.value = double.parse(double.parse(data2['pm25Con'][0]['value']).toStringAsFixed(2));
      }
      else {
        pm25Con.value = double.parse(double.parse(data2['pm25Con'][0]['value']).toStringAsFixed(2));
        coCon.value = double.parse(double.parse(data2['coCon'][0]['value']).toStringAsFixed(2));
      }
    }
    if(pm25Con.value >= 0.0 && pm25Con.value <= 12.05){
      bpLo = 0.0;
      bpHi = 12.05;
      aqiLo = 0;
      aqiHi = 53;
    } else if(pm25Con.value > 12.05 && pm25Con.value <= 35.45){
      bpLo = 12.05;
      bpHi = 35.45;
      aqiLo = 54;
      aqiHi = 100;
    } else if(pm25Con.value > 35.45 && pm25Con.value <= 55.45){
      bpLo = 35.45;
      bpHi = 55.45;
      aqiLo = 101;
      aqiHi = 150;
    } else if(pm25Con.value > 55.45 && pm25Con.value <= 150.45){
      bpLo = 55.45;
      bpHi = 150.45;
      aqiLo = 151;
      aqiHi = 200;
    } else if(pm25Con.value > 150.45 && pm25Con.value <= 250.45){
      bpLo = 150.45;
      bpHi = 250.45;
      aqiLo = 201;
      aqiHi = 300;
    } else if(pm25Con.value > 250.45 && pm25Con.value <= 350.45){
      bpLo = 250.45;
      bpHi = 350.45;
      aqiLo = 301;
      aqiHi = 400;
    } else if(pm25Con.value > 350.45 && pm25Con.value <= 500.4){
      bpLo = 350.45;
      bpHi = 500.4;
      aqiLo = 401;
      aqiHi = 500;
    }
    // print(((((aqiHi - aqiLo)*(conPm - bpLo))/(bpHi - bpLo)) + aqiLo).toStringAsFixed(0));
    // int aqiCal = 124;
    int aqiCal = int.parse(((((aqiHi - aqiLo)*((pm25Con.value) - bpLo))/(bpHi - bpLo)) + aqiLo).toStringAsFixed(0));
    // var body = json.encode({
    //   'ts' : endTs,
    //   'values' : {
    //     'AQI' : aqiCal
    //   }
    // });
    // print(body);
    // await http.post(
    //     Uri.parse('https://${tbLinks[i]}/api/v1/$accessToken/telemetry'),
    //     body: body
    // );
    var url = Uri.parse('https://${tbLinks[i]}/api/plugins/telemetry/DEVICE/${widget.devId}/values/timeseries?keys=humidity,temperature,pressure,no2Con');
    var response = await http.get(
        url,
        headers: {
          'Content-Type':'application/json',
          'Accept':'application/json',
          'X-Authorization': bearerToken,
        }
    );
    var data = await json.decode(response.body);
    airQuality.value = aqiCal;
    heightPM25.value = ((pm25Con.value) / maxPM25) *320;
    if(pm25Con.value <= safePM25){
      colorPM25.value = 0xff64e35f;
    }
    else if(pm25Con.value > safePM25 && pm25Con.value <= (maxPM25 * 0.3)){
      colorPM25.value = 0xffdfe35f;
    }
    else if(pm25Con.value > (maxPM25 * 0.3) && pm25Con.value <= maxPM25){
      colorPM25.value = 0xfff76060;
    }
    heightAQI.value = ((airQuality.value) / 500) * 320;
    if(airQuality.value == 0){
      healthStatus.value = "--";
      healthColor.value = 0xff03fc7f;
    }
    else if(airQuality.value <= 50 && airQuality.value > 0){
      healthColor.value = 0xff2cf61a;
      healthStatus.value = "Good";
    }
    else if(airQuality.value <= 100 && airQuality.value > 50){
      healthColor.value = 0xffedf93c;
      healthStatus.value = "Moderate";
    }
    else if(airQuality.value > 100 && airQuality.value <= 150){
      healthColor.value = 0xffff0303;
      healthStatus.value = "Unhealthy\nfor Sensitive Groups";
    }
    else if(airQuality.value > 150 && airQuality.value <= 200){
      healthColor.value = 0xffff9d00;
      healthStatus.value = "Unhealthy";
    }
    else if(airQuality.value > 200 && airQuality.value <= 300){
      healthColor.value = 0xffe730c4;
      healthStatus.value = "Very Unhealthy";
    }
    else if(airQuality.value > 300 && airQuality.value <= 500){
      healthColor.value = 0xffab0f3e;
      healthStatus.value = "Hazardous";
    }
    var latestDataTime = DateTime.fromMillisecondsSinceEpoch(data['temperature'][0]['ts']);
    var timeDifference = DateTime.now().difference(latestDataTime);
    if(timeDifference.inMinutes >= 30){
      showStaleWarning.value = true;
    }
    else{
      showStaleWarning.value = false;
    }
    // int latestDataTime = data['temperature'][0]['ts'];
    // int timeDifference = DateTime.now().millisecondsSinceEpoch - latestDataTime;
    // print(timeDifference);
    // int time30Min = int.parse(DateTime(0,0,0,0,30,0,0,0).millisecondsSinceEpoch.toString());
    // print(time30Min);
    // if(timeDifference > time30Min){
    //   showStaleWarning.value = true;
    // }
    // else{
    //   showStaleWarning.value = false;
    // }
    humidity.value = int.parse(await data['humidity'][0]['value']);
    temperature.value = int.parse(await data['temperature'][0]['value']);
    pressure.value = (double.parse(await data['pressure'][0]['value']) ~/ 1);
    if(pressure.value > 2000){
      pressure.value = (double.parse(await data['pressure'][0]['value']) ~/ 100);
    } else{
      pressure.value = (double.parse(await data['pressure'][0]['value']) ~/ 1);
    }
    no2Con.value = double.parse(await data['no2Con'][0]['value']);
    heightNO.value = ((no2Con.value) / maxNO) * 320;
    if(no2Con.value <= safeNO){
      colorNO2.value = 0xff64e35f;
    }
    else if(no2Con.value > safeNO && no2Con.value <= (maxNO * 0.6)){
      colorNO2.value = 0xffdfe35f;
    }
    else if(no2Con.value > (maxNO * 0.6) && no2Con.value <= maxNO){
      colorNO2.value = 0xfff76060;
    }
    heightCO.value = ((coCon.value) / maxCO) * 320;
    if(coCon.value <= safeCO){
      colorCO.value = 0xff64e35f;
    }
    else if(coCon.value > safeCO && coCon.value <= (maxCO * 0.4)){
      colorCO.value = 0xffdfe35f;
    }
    else if(coCon.value > (maxCO * 0.4) && coCon.value <= maxCO){
      colorCO.value = 0xfff76060;
    }
    await functions.save('lastAQI${widget.devIndex}.txt', airQuality.value.toString());
    await functions.save('lastTemp${widget.devIndex}.txt', temperature.value.toString());
    await functions.save('lastHumid${widget.devIndex}.txt', humidity.value.toString());
    await functions.save('lastPressure${widget.devIndex}.txt', pressure.value.toString());
    await functions.save('lastPm25Con${widget.devIndex}.txt', pm25Con.value.toString());
    await functions.save('lastNo2Con${widget.devIndex}.txt', no2Con.value.toString());
    await functions.save('lastCoCon${widget.devIndex}.txt', coCon.value.toString());
    return json.decode(response.body);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        SingleChildScrollView(
          // physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(10 * MediaQuery.of(context).size.width / screenWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: 40 * MediaQuery.of(context).size.width / screenWidth,
                ),

                ValueListenableBuilder(
                    valueListenable: healthColor,
                    builder: (BuildContext context, int color, _){
                      return ValueListenableBuilder(
                          valueListenable: airQuality,
                          builder: (BuildContext context, int value, _){
                            return SfRadialGauge(
                              axes: <RadialAxis>[
                                RadialAxis(
                                    minimum: 0,
                                    maximum: 500,
                                    showTicks: false,
                                    showLabels: false,
                                    axisLineStyle: AxisLineStyle(
                                        thickness: 20 * MediaQuery.of(context).size.width / screenWidth,
                                        cornerStyle: CornerStyle.bothCurve
                                    ),
                                    pointers: <GaugePointer>[
                                      RangePointer(
                                          value: value.toDouble(),
                                          color: Color(color),
                                          width: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          cornerStyle: CornerStyle.bothCurve,
                                          enableAnimation: true,
                                          animationType: AnimationType.easeOutBack,
                                          animationDuration: 1300
                                      ),
                                    ],
                                    annotations: <GaugeAnnotation>[
                                      GaugeAnnotation(
                                          axisValue: 250,
                                          widget: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: <Widget>[
                                              SizedBox(
                                                width: 100 * MediaQuery.of(context).size.width / screenWidth,
                                                height: 100 * MediaQuery.of(context).size.width / screenWidth,
                                                child: FittedBox(
                                                  fit: BoxFit.fitHeight,
                                                  child: Image(
                                                    image: (value > 0 && value <= 50) ? const AssetImage('assets/icons/Good.png') : ((value > 50 && value <= 100) ? const AssetImage('assets/icons/Moderate.png') :((value > 100 && value <= 150) ? const AssetImage('assets/icons/UnhealthySG.png') : ((value > 150 && value <= 200) ? const AssetImage('assets/icons/Unhealthy.png') : ((value > 200 && value <= 300) ? const AssetImage('assets/icons/VeryUnhealthy.png') : const AssetImage('assets/icons/Hazardous.png'))))),
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.only(top: 0.2 * MediaQuery.of(context).size.width / screenWidth),
                                                child: Text(
                                                  "$value",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 40  * MediaQuery.of(context).size.width / screenWidth,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.only(top: 0.1 * MediaQuery.of(context).size.width / screenWidth),
                                                child: Text(
                                                  "US AQI",
                                                  style: TextStyle(
                                                    fontSize: 25 * MediaQuery.of(context).size.width / screenWidth,
                                                  ),
                                                ),
                                              ),
                                              // Padding(
                                              //   padding: EdgeInsets.only(top: 10 * MediaQuery.of(context).size.width / screenWidth),
                                              //   child: ValueListenableBuilder(
                                              //     valueListenable: healthStatus,
                                              //     builder: (BuildContext context, String msg, _){
                                              //       return Text(
                                              //         "$msg",
                                              //         style: TextStyle(
                                              //           fontSize: 25 * MediaQuery.of(context).size.width / screenWidth,
                                              //         ),
                                              //         textAlign: TextAlign.center,
                                              //       );
                                              //     },
                                              //   ),
                                              // ),
                                            ],
                                          )
                                      ),
                                      GaugeAnnotation(
                                        axisValue: 250,
                                        positionFactor:1,
                                        angle: 90,
                                        widget: ValueListenableBuilder(
                                          valueListenable: healthStatus,
                                          builder: (BuildContext context, String msg, _){
                                            return Text(
                                              msg,
                                              style: TextStyle(
                                                fontSize: 25 * MediaQuery.of(context).size.width / screenWidth,
                                              ),
                                              textAlign: TextAlign.center,
                                            );
                                          },
                                        ),
                                      )
                                    ]
                                )
                              ],
                            );
                          }
                      );
                    }
                ),
                // Padding(padding: EdgeInsets.fromLTRB(
                //   0, 2 * MediaQuery.of(context).size.width / screenWidth, 0, 0
                // )),
                // ValueListenableBuilder(
                //   valueListenable: healthStatus,
                //   builder: (BuildContext context, String msg, _){
                //     return Text(
                //       "* $msg",
                //       style: TextStyle(
                //         fontSize: 25 * MediaQuery.of(context).size.width / screenWidth,
                //       ),
                //     );
                //   },
                // ),
                Padding(
                  padding: EdgeInsets.only(top: 8.0 * MediaQuery.of(context).size.width / screenWidth),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    // height: 50,
                    // color: Colors.grey,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 65 * MediaQuery.of(context).size.width / screenWidth,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(8 * MediaQuery.of(context).size.width / screenWidth),
                                child: FittedBox(
                                  fit: BoxFit.fitHeight,
                                  child: ValueListenableBuilder(
                                    valueListenable: temperature,
                                    builder: (BuildContext context, int value, Widget? child){
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: <Widget>[
                                          child!,
                                          Padding(padding: EdgeInsets.all(7 * MediaQuery.of(context).size.width / screenWidth)),
                                          Text(
                                            "$value \u00B0 C",
                                            style: TextStyle(
                                              fontSize: 20 * MediaQuery.of(context).size.width / screenWidth,
                                            ),
                                            textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                        ],
                                      );
                                    },
                                    child: Icon(
                                      AppIcon.temperature_high,
                                      color: Colors.red,
                                      size: 20 * MediaQuery.of(context).size.width / screenWidth,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(padding: EdgeInsets.all(3 * MediaQuery.of(context).size.width / screenWidth)),
                        Container(
                          width: 2 * MediaQuery.of(context).size.width / screenWidth,
                          height: 35 * MediaQuery.of(context).size.width / screenWidth,
                          color: Colors.grey[300],
                        ),
                        Padding(padding: EdgeInsets.all(3 * MediaQuery.of(context).size.width / screenWidth)),
                        Expanded(
                          child: SizedBox(
                            height: 65 * MediaQuery.of(context).size.width / screenWidth,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(5 * MediaQuery.of(context).size.width / screenWidth),
                                child: FittedBox(
                                  fit: BoxFit.fitHeight,
                                  child: ValueListenableBuilder(
                                    valueListenable: humidity,
                                    builder: (BuildContext context, int value, Widget? child){
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: <Widget>[
                                          child!,
                                          Padding(padding: EdgeInsets.all(3 * MediaQuery.of(context).size.width / screenWidth)),
                                          Text(
                                            "$value %",
                                            style: TextStyle(
                                              fontSize: 20 * MediaQuery.of(context).size.width / screenWidth,
                                            ),
                                            textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                        ],
                                      );
                                    },
                                    child: Icon(
                                      AppIcon.water_drop,
                                      color: Colors.blue,
                                      size: 20 * MediaQuery.of(context).size.width / screenWidth,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(padding: EdgeInsets.all(3 * MediaQuery.of(context).size.width / screenWidth)),
                        Container(
                          width: 2 * MediaQuery.of(context).size.width / screenWidth,
                          height: 35 * MediaQuery.of(context).size.width / screenWidth,
                          color: Colors.grey[300],
                        ),
                        Padding(padding: EdgeInsets.all(3 * MediaQuery.of(context).size.width / screenWidth)),
                        Expanded(
                          child: SizedBox(
                            height: 65 * MediaQuery.of(context).size.width / screenWidth,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(12 * MediaQuery.of(context).size.width / screenWidth),
                                child: FittedBox(
                                  fit: BoxFit.fitHeight,
                                  child: ValueListenableBuilder(
                                    valueListenable: pressure,
                                    builder: (BuildContext context, int value, _){
                                      return Text(
                                        "$value hPa",
                                        style: TextStyle(
                                          fontSize: 20 * MediaQuery.of(context).size.width / screenWidth,
                                        ),
                                        textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.all(15 * MediaQuery.of(context).size.width / screenWidth)),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20 * MediaQuery.of(context).size.width / screenWidth)),
                    side: BorderSide(
                      color: Colors.black38,
                      width: 3 * MediaQuery.of(context).size.width / screenWidth,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: 280 * MediaQuery.of(context).size.width / screenWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(20 * MediaQuery.of(context).size.width / screenWidth)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const Spacer(),
                          SizedBox(
                            height: 40 * MediaQuery.of(context).size.width / screenWidth,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.fitHeight,
                                child: Text(
                                  "Concentrations",
                                  style: TextStyle(
                                      fontSize: 25 * MediaQuery.of(context).size.width / screenWidth,
                                      fontWeight: FontWeight.bold
                                  ),
                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),
                          ValueListenableBuilder(
                            valueListenable: colorNO2,
                            builder: (context, int colorVal, _){
                              return ValueListenableBuilder(
                                valueListenable: colorPM25,
                                builder: (context, int colorVal, _){
                                  return ValueListenableBuilder(
                                    valueListenable: colorCO,
                                    builder: (context, int colorValue, _){
                                      return Padding(
                                        padding: EdgeInsets.only(left: 25 * MediaQuery.of(context).size.width / screenWidth, right: 25 * MediaQuery.of(context).size.width / screenWidth),
                                        child: Table(
                                          border: TableBorder.all(color: Colors.black, width: 2 * MediaQuery.of(context).size.width / screenWidth, style: BorderStyle.none),
                                          children: <TableRow>[
                                            TableRow(
                                                decoration: BoxDecoration(
                                                  color: Color(colorVal),
                                                  borderRadius: BorderRadius.all(Radius.circular(20 * MediaQuery.of(context).size.width / screenWidth)),
                                                ),
                                                children: <Widget>[
                                                  TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: SizedBox(
                                                        height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                                        child: Center(
                                                          child: FittedBox(
                                                            fit: BoxFit.fitHeight,
                                                            child: Text(
                                                              "PM2.5",
                                                              style: TextStyle(
                                                                  fontSize: 24 * MediaQuery.of(context).size.width / screenWidth
                                                              ),
                                                              textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  ),
                                                  TableCell(
                                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                                    child: SizedBox(
                                                      height: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                      child: Center(
                                                        child: FittedBox(
                                                            fit: BoxFit.fitHeight,
                                                            child: Icon(Icons.arrow_forward_outlined, size: 24 * MediaQuery.of(context).size.width / screenWidth)
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: ValueListenableBuilder(
                                                        valueListenable: pm25Con,
                                                        builder: (context, double val, _){
                                                          return SizedBox(
                                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                                            child: Center(
                                                              child: FittedBox(
                                                                fit: BoxFit.fitHeight,
                                                                child: Text(
                                                                  "$val \u03BCg/m\u00B3",
                                                                  style: TextStyle(
                                                                      fontSize: 24 * MediaQuery.of(context).size.width / screenWidth
                                                                  ),
                                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      )
                                                  ),
                                                ]
                                            ),
                                            TableRow(
                                                children: <Widget>[
                                                  Padding(padding: EdgeInsets.all(4 * MediaQuery.of(context).size.width / screenWidth)),
                                                  Padding(padding: EdgeInsets.all(4 * MediaQuery.of(context).size.width / screenWidth)),
                                                  Padding(padding: EdgeInsets.all(4 * MediaQuery.of(context).size.width / screenWidth)),
                                                ]
                                            ),
                                            TableRow(
                                                decoration: BoxDecoration(
                                                  color: Color(colorVal),
                                                  borderRadius: BorderRadius.all(Radius.circular(20 * MediaQuery.of(context).size.width / screenWidth)),
                                                ),
                                                children: <Widget>[
                                                  TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: SizedBox(
                                                        height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                                        child: Center(
                                                          child: FittedBox(
                                                            fit: BoxFit.fitHeight,
                                                            child: Text(
                                                              "NO2",
                                                              style: TextStyle(
                                                                  fontSize: 24 * MediaQuery.of(context).size.width / screenWidth
                                                              ),
                                                              textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  ),
                                                  TableCell(
                                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                                    child: SizedBox(
                                                      height: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                      child: Center(
                                                        child: FittedBox(
                                                            fit: BoxFit.fitHeight,
                                                            child: Icon(Icons.arrow_forward_outlined, size: 24 * MediaQuery.of(context).size.width / screenWidth)
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: ValueListenableBuilder(
                                                        valueListenable: no2Con,
                                                        builder: (context, double val, _){
                                                          return SizedBox(
                                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                                            child: Center(
                                                              child: FittedBox(
                                                                fit: BoxFit.fitHeight,
                                                                child: Text(
                                                                  "$val ppm",
                                                                  style: TextStyle(
                                                                      fontSize: 24 * MediaQuery.of(context).size.width / screenWidth
                                                                  ),
                                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      )
                                                  ),
                                                ]
                                            ),
                                            TableRow(
                                                children: <Widget>[
                                                  Padding(padding: EdgeInsets.all(4 * MediaQuery.of(context).size.width / screenWidth)),
                                                  Padding(padding: EdgeInsets.all(4 * MediaQuery.of(context).size.width / screenWidth)),
                                                  Padding(padding: EdgeInsets.all(4 * MediaQuery.of(context).size.width / screenWidth)),
                                                ]
                                            ),
                                            TableRow(
                                                decoration: BoxDecoration(
                                                  color: Color(colorValue),
                                                  borderRadius: BorderRadius.all(Radius.circular(20 * MediaQuery.of(context).size.width / screenWidth)),
                                                ),
                                                children: <Widget>[
                                                  TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: SizedBox(
                                                        height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                                        child: Center(
                                                          child: FittedBox(
                                                            fit: BoxFit.fitHeight,
                                                            child: Text(
                                                              "CO",
                                                              style: TextStyle(
                                                                  fontSize: 24 * MediaQuery.of(context).size.width / screenWidth
                                                              ),
                                                              textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  ),
                                                  TableCell(
                                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                                    child: SizedBox(
                                                      height: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                      child: Center(
                                                        child: FittedBox(
                                                            fit: BoxFit.fitHeight,
                                                            child: Icon(Icons.arrow_forward_outlined, size: 24 * MediaQuery.of(context).size.width / screenWidth)
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: ValueListenableBuilder(
                                                        valueListenable: coCon,
                                                        builder: (context, double val, _){
                                                          return SizedBox(
                                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                                            child: Center(
                                                              child: FittedBox(
                                                                fit: BoxFit.fitHeight,
                                                                child: Text(
                                                                  "$val ppm",
                                                                  style: TextStyle(
                                                                      fontSize: 24 * MediaQuery.of(context).size.width / screenWidth
                                                                  ),
                                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      )
                                                  ),
                                                ]
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.all(30 * MediaQuery.of(context).size.width / screenWidth)),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20 * MediaQuery.of(context).size.width / screenWidth)),
                    side: BorderSide(
                      color: Colors.black38,
                      width: 3 * MediaQuery.of(context).size.width / screenWidth,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 530 * MediaQuery.of(context).size.width / screenWidth,
                      child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 30 * MediaQuery.of(context).size.width / screenWidth, top:20 * MediaQuery.of(context).size.width / screenWidth),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  height: 40 * MediaQuery.of(context).size.width / screenWidth,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.fitHeight,
                                      child: Text(
                                        "Exposures",
                                        style: TextStyle(
                                            fontSize: 30 * MediaQuery.of(context).size.width / screenWidth
                                        ),
                                        textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    const Spacer(),
                                    Stack(
                                      alignment: AlignmentDirectional.centerStart,
                                      clipBehavior: Clip.none,
                                      children: <Widget>[
                                        SizedBox(
                                          width: 80 * MediaQuery.of(context).size.width / screenWidth,
                                          height: 420 * MediaQuery.of(context).size.width / screenWidth,
                                        ),
                                        Positioned(
                                          left: 25 * MediaQuery.of(context).size.width / screenWidth,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: AlignmentDirectional.bottomCenter,
                                            children: <Widget>[
                                              Container(
                                                width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                height: 320 * MediaQuery.of(context).size.width / screenWidth,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                              ValueListenableBuilder(
                                                valueListenable: heightAQI,
                                                builder: (context, double value, _){
                                                  return ValueListenableBuilder(
                                                    valueListenable: healthColor,
                                                    builder: (context, int colorVal, _){
                                                      return AnimatedContainer(
                                                        width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                        height: value * MediaQuery.of(context).size.width / screenWidth,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                          color: Color(colorVal),
                                                        ),
                                                        duration: const Duration(milliseconds: 800),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                              Positioned(
                                                bottom: safeHeightAQI * MediaQuery.of(context).size.width / screenWidth,
                                                child: Container(
                                                  width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                  height: 2 * MediaQuery.of(context).size.width / screenWidth,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          left: 10 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (41 + safeHeightAQI) * MediaQuery.of(context).size.width / screenWidth,
                                          child: Icon(
                                            Icons.arrow_right_sharp,
                                            // color: ,
                                            size: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                        ),
                                        Positioned(
                                          left: -2 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (44 + safeHeightAQI) * MediaQuery.of(context).size.width / screenWidth,
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: SizedBox(
                                              height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "60",
                                                  style: TextStyle(
                                                      fontSize: 14 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 33 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          child: SizedBox(
                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "AQI",
                                                  style: TextStyle(
                                                      fontSize: 20 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: AlignmentDirectional.centerStart,
                                      children: <Widget>[
                                        Container(
                                          width: 80 * MediaQuery.of(context).size.width / screenWidth,
                                          height: 420 * MediaQuery.of(context).size.width / screenWidth,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                          ),
                                        ),
                                        Positioned(
                                          left: 25 * MediaQuery.of(context).size.width / screenWidth,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: AlignmentDirectional.bottomCenter,
                                            children: <Widget>[
                                              Container(
                                                width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                height: 320 * MediaQuery.of(context).size.width / screenWidth,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                              ValueListenableBuilder(
                                                valueListenable: heightNO,
                                                builder: (context, double value, _){
                                                  return ValueListenableBuilder(
                                                    valueListenable: colorNO2,
                                                    builder: (context, int colorVal, _){
                                                      return AnimatedContainer(
                                                        width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                        height: value * MediaQuery.of(context).size.width / screenWidth,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                          color: Color(colorVal),
                                                        ),
                                                        duration: const Duration(milliseconds: 800),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                              Positioned(
                                                bottom: safeHeightNO * MediaQuery.of(context).size.width / screenWidth,
                                                child: Container(
                                                  width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                  height: 2 * MediaQuery.of(context).size.width / screenWidth,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          left: 10 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (41 + safeHeightNO) * MediaQuery.of(context).size.width / screenWidth,
                                          child: Icon(
                                            Icons.arrow_right_sharp,
                                            // color: ,
                                            size: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                        ),
                                        Positioned(
                                          left: -3 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (34 + safeHeightNO) * MediaQuery.of(context).size.width / screenWidth,
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: SizedBox(
                                              height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "$safeNO ppm",
                                                  style: TextStyle(
                                                      fontSize: 14 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 35 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          child: SizedBox(
                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "NO2",
                                                  style: TextStyle(
                                                      fontSize: 20 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Stack(
                                      alignment: AlignmentDirectional.centerStart,
                                      clipBehavior: Clip.none,
                                      children: <Widget>[
                                        Container(
                                          width: 80 * MediaQuery.of(context).size.width / screenWidth,
                                          height: 420 * MediaQuery.of(context).size.width / screenWidth,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                          ),
                                        ),
                                        Positioned(
                                          left: 25 * MediaQuery.of(context).size.width / screenWidth,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: AlignmentDirectional.bottomCenter,
                                            children: <Widget>[
                                              Container(
                                                width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                height: 320 * MediaQuery.of(context).size.width / screenWidth,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                              ValueListenableBuilder(
                                                valueListenable: heightPM25,
                                                builder: (context, double value, _){
                                                  return ValueListenableBuilder(
                                                    valueListenable: colorPM25,
                                                    builder: (context, int colorVal, _){
                                                      return AnimatedContainer(
                                                        width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                        height: value * MediaQuery.of(context).size.width / screenWidth,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                          color: Color(colorVal),
                                                        ),
                                                        duration: const Duration(milliseconds: 800),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                              Positioned(
                                                bottom: safeHeightPM25 * MediaQuery.of(context).size.width / screenWidth,
                                                child: Container(
                                                  width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                  height: 2 * MediaQuery.of(context).size.width / screenWidth,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          left: 10 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (41 + safeHeightPM25) * MediaQuery.of(context).size.width / screenWidth,
                                          child: Icon(
                                            Icons.arrow_right_sharp,
                                            // color: ,
                                            size: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                        ),
                                        Positioned(
                                          left: -5 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (32 + safeHeightPM25) * MediaQuery.of(context).size.width / screenWidth,
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: SizedBox(
                                              height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "$safePM25 \u03BCg/m\u00B3",
                                                  style: TextStyle(
                                                      fontSize: 14 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 28 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          child: SizedBox(
                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "PM2.5",
                                                  style: TextStyle(
                                                      fontSize: 20 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Stack(
                                      alignment: AlignmentDirectional.centerStart,
                                      clipBehavior: Clip.none,
                                      children: <Widget>[
                                        Container(
                                          width: 80 * MediaQuery.of(context).size.width / screenWidth,
                                          height: 420 * MediaQuery.of(context).size.width / screenWidth,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                          ),
                                        ),
                                        Positioned(
                                          left: 25 * MediaQuery.of(context).size.width / screenWidth,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: AlignmentDirectional.bottomCenter,
                                            children: <Widget>[
                                              Container(
                                                width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                height: 320 * MediaQuery.of(context).size.width / screenWidth,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                              ValueListenableBuilder(
                                                valueListenable: heightCO,
                                                builder: (context, double value, _){
                                                  return ValueListenableBuilder(
                                                    valueListenable: colorCO,
                                                    builder: (context, int colorVal, _){
                                                      return AnimatedContainer(
                                                        width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                        height: value * MediaQuery.of(context).size.width / screenWidth,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.all(Radius.circular(8 * MediaQuery.of(context).size.width / screenWidth)),
                                                          color: Color(colorVal),
                                                        ),
                                                        duration: const Duration(milliseconds: 800),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                              Positioned(
                                                bottom: safeHeightCO * MediaQuery.of(context).size.width / screenWidth,
                                                child: Container(
                                                  width: 50 * MediaQuery.of(context).size.width / screenWidth,
                                                  height: 2 * MediaQuery.of(context).size.width / screenWidth,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          left: 10 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (41 + safeHeightCO) * MediaQuery.of(context).size.width / screenWidth,
                                          child: Icon(
                                            Icons.arrow_right_sharp,
                                            // color: ,
                                            size: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          ),
                                        ),
                                        Positioned(
                                          left: -3 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: (33 + safeHeightCO) * MediaQuery.of(context).size.width / screenWidth,
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: SizedBox(
                                              height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "$safeCO ppm",
                                                  style: TextStyle(
                                                      fontSize: 14 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 40 * MediaQuery.of(context).size.width / screenWidth,
                                          bottom: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          child: SizedBox(
                                            height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Text(
                                                  "CO",
                                                  style: TextStyle(
                                                      fontSize: 20 * MediaQuery.of(context).size.width / screenWidth
                                                  ),
                                                  textScaleFactor: 0.9 * MediaQuery.of(context).size.width / screenWidth,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(flex: 3),
                                  ],
                                ),
                                // Spacer(),
                                // Container(
                                //   child: Center(
                                //     child: Row(
                                //       mainAxisAlignment: MainAxisAlignment.center,
                                //       // crossAxisAlignment: CrossAxisAlignment.center,
                                //       children: <Widget>[
                                //         Spacer(),
                                //         Container(
                                //           color: Colors.grey,
                                //           child: FittedBox(
                                //             fit: BoxFit.fitWidth,
                                //             child: Text(
                                //               "Key : "
                                //             ),
                                //           ),
                                //         ),
                                //         RotatedBox(
                                //           quarterTurns: 3,
                                //           child: Container(
                                //             color: Colors.grey,
                                //             child: FittedBox(
                                //               fit: BoxFit.fitWidth,
                                //               child: Text("value",style: TextStyle(fontSize: 14),textScaleFactor: 0.9),
                                //             ),
                                //           ),
                                //         ),
                                //         Container(
                                //           color: Colors.grey,
                                //           child: Icon(Icons.arrow_right_sharp),
                                //         ),
                                //         Container(
                                //           width: 50,
                                //           height: 2,
                                //           color: Colors.black,
                                //         ),
                                //         Spacer(),
                                //         Container(
                                //           width: 75,
                                //           color: Colors.grey,
                                //           child: FittedBox(
                                //             fit: BoxFit.fitWidth,
                                //             child: Text("Safe Values"),
                                //           ),
                                //         ),
                                //         Spacer()
                                //       ],
                                //     ),
                                //   ),
                                // ),
                                // Spacer(),
                              ],
                            ),
                          )
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 50 * MediaQuery.of(context).size.width / screenWidth,
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: showStaleWarning,
          builder: (BuildContext context, bool staleWarn, _){
            return Container(
              child: staleWarn ?
              ValueListenableBuilder(
                valueListenable: warningMinMax,
                builder: (BuildContext context, bool minimize, _){
                  return Container(
                    child: minimize ?
                    Positioned(
                      top: 10 * MediaQuery.of(context).size.width / screenWidth,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Opacity(
                            opacity: 0.6,
                            child: Container(
                              width: 400 * MediaQuery.of(context).size.width / screenWidth,
                              height: 110 * MediaQuery.of(context).size.width / screenWidth,
                              decoration: BoxDecoration(
                                color: Colors.yellow[300],
                                borderRadius: BorderRadius.circular(10 * MediaQuery.of(context).size.width / screenWidth),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 400 * MediaQuery.of(context).size.width / screenWidth,
                            height: 110 * MediaQuery.of(context).size.width / screenWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 35 * MediaQuery.of(context).size.width / screenWidth
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SizedBox(
                                    width: 40 * MediaQuery.of(context).size.width / screenWidth,
                                    height: 20 * MediaQuery.of(context).size.width / screenWidth,
                                  ),
                                ),
                                Expanded(
                                  flex: 10,
                                  child: SizedBox(
                                    width: 250 * MediaQuery.of(context).size.width / screenWidth,
                                    height: 120 * MediaQuery.of(context).size.width / screenWidth,
                                    // color: Colors.red,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: EdgeInsets.only(top: 10 * MediaQuery.of(context).size.width / screenWidth),
                                            child: FittedBox(
                                              fit: BoxFit.fitHeight,
                                              child: Text(
                                                'Outdated Data',
                                                style: TextStyle(
                                                    fontSize: 25 * MediaQuery.of(context).size.width / screenWidth,
                                                    fontWeight: FontWeight.bold
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 20 * MediaQuery.of(context).size.width / screenWidth,
                                          height: 5 * MediaQuery.of(context).size.width / screenWidth,
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: Padding(
                                            padding: EdgeInsets.only(bottom: 15 * MediaQuery.of(context).size.width / screenWidth, right: 15 * MediaQuery.of(context).size.width / screenWidth),
                                            child: FittedBox(
                                              fit: BoxFit.fitWidth,
                                              child: Text(
                                                'The data is more than 30 minutes old and may not\nrepresent the current environmental situation.',
                                                style: TextStyle(
                                                    fontSize: 18 * MediaQuery.of(context).size.width / screenWidth
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Positioned(
                            top: 2 * MediaQuery.of(context).size.width / screenWidth,
                            right: 2 * MediaQuery.of(context).size.width / screenWidth,
                            child: IconButton(
                              onPressed: () {
                                warningMinMax.value = false;
                              },
                              icon: Icon(Icons.close, size: 25 * MediaQuery.of(context).size.width / screenWidth),
                            ),
                          )
                        ],
                      ),
                    ) :
                    Positioned(
                      top: 2 * MediaQuery.of(context).size.width / screenWidth,
                      right: 2 * MediaQuery.of(context).size.width / screenWidth,
                      child: Container(
                        width: 50 * MediaQuery.of(context).size.width / screenWidth,
                        height: 50 * MediaQuery.of(context).size.width / screenWidth,
                        decoration: BoxDecoration(
                          color: Colors.yellow[600],
                          borderRadius: BorderRadius.circular(10 * MediaQuery.of(context).size.width / screenWidth),
                        ),
                        child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.warning_amber_rounded,),
                              onPressed: (){
                                warningMinMax.value = true;
                              },
                            )
                        ),
                      ),
                    ),
                  );
                },
              )
                  : null,
            );
          },
        )
      ],
    );
  }
}
