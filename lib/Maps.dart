import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:envirosense/ValueNotifiers.dart';

class MapPage extends StatefulWidget {
  final double latValue;
  final double longValue;
  final double zoom;
  const MapPage({Key? key, required this.latValue, required this.longValue, required this.zoom}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  void initState() {
    super.initState();
  }
  final Map<String, Marker> _markers = {};
  final Location _location = Location();

  void _onMapCreated(controller) {
    setState(() {
      _location.getLocation();
      _markers.clear();
      for(int i = 0; i < location.value.length; i++){
        final marker = Marker(
          markerId: MarkerId(location.value[i]),
          position: LatLng(double.parse(latitude.value[i]), double.parse(longitude.value[i])),
          infoWindow: InfoWindow(
              title: "AQWMS Node ${i+1}",
              snippet: "${location.value[i]}"
          ),
        );
        _markers[location.value[i]] = marker;
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GoogleMap(
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        compassEnabled: true,
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.latValue,widget.longValue),
          zoom: widget.zoom,
        ),
        markers: _markers.values.toSet(),
        mapToolbarEnabled: true,
      ),
    );
  }
}
