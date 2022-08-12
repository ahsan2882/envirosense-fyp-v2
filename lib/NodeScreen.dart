import 'package:flutter/material.dart';
import 'package:envirosense/ValueNotifiers.dart';
import 'package:envirosense/Maps.dart';
import 'package:envirosense/DataScreen.dart';

final ValueNotifier<String> locationName = ValueNotifier<String>("Loading");

class Node extends StatefulWidget {
  final String deviceId;
  final int index;
  final int lastAqi;
  final int lastTem;
  final int lastHum;
  final int lastPres;
  final double lastPm;
  final double lastNo2;
  final double lastCo;
  const Node({Key? key, required this.deviceId, required this.index, required this.lastAqi, required this.lastTem, required this.lastHum, required this.lastPres, required this.lastPm, required this.lastNo2, required this.lastCo}) : super(key: key);

  @override
  State<Node> createState() => _NodeState();
}

class _NodeState extends State<Node> {

  @override
  void initState() {
    locationName.value = location.value[widget.index];
    super.initState();
  }
  @override
  void dispose() {
    super.dispose();
  }
  int selectedIndex = 0;
  List<Widget> screens = <Widget>[
    const DataPage(devId: "h", devIndex: 0, lastAqi: 0, lastCo: 0.0, lastHum: 0, lastNo2: 0.0, lastPm: 0.0, lastPres: 0, lastTem: 0),
    MapPage(latValue: double.parse(latitude.value[1]), longValue: double.parse(longitude.value[0]), zoom: 16.0),
    // StatisticsPage(devId: "h")
  ];
  @override
  Widget build(BuildContext context) {
    screens[0] = DataPage(devId: widget.deviceId, devIndex: widget.index, lastPres: widget.lastPres, lastTem: widget.lastTem, lastPm: widget.lastPm, lastNo2: widget.lastNo2, lastHum: widget.lastHum, lastCo: widget.lastCo, lastAqi: widget.lastAqi);
    screens[1] = MapPage(latValue: double.parse(latitude.value[widget.index]), longValue: double.parse(longitude.value[widget.index]), zoom: 16.0);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.square(60.0 * MediaQuery.of(context).size.width / screenWidth),
        child: AppBar(
          elevation: 10 * MediaQuery.of(context).size.width / screenWidth,
          title: Text(locationName.value),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.add_location_alt_sharp,
            ),
            label: 'MyAir',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.map,
            ),
            label: 'Map',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.bar_chart_sharp),
          //   label: 'Statistics',
          // ),
        ],
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        selectedFontSize: 15 * MediaQuery.of(context).size.width / screenWidth,
        unselectedFontSize: 15 * MediaQuery.of(context).size.width / screenWidth,
        iconSize: 27 * MediaQuery.of(context).size.width / screenWidth,
      ),
      body: screens.elementAt(selectedIndex),
    );
  }
}
