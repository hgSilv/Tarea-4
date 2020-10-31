import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share/share.dart';
import 'package:geocoder/geocoder.dart';

class HomeMap extends StatefulWidget {
  const HomeMap({Key key}) : super(key: key);

  @override
  _HomeMapState createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  Set<Marker> _mapMarkers = Set();
  Set<Polygon> _mapPolygons = Set();
  GoogleMapController _mapController;
  Position _currentPosition;
  Position _defaultPosition = Position(
    latitude: 20.60837331,
    longitude: -103.41482732,
  );
  bool _seePolygons = false;
  TextEditingController _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getCurrentPosition(),
      builder: (context, result) {
        if (result.error == null) {
          if (_currentPosition == null) _currentPosition = _defaultPosition;
          return Scaffold(
            body: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition.latitude,
                      _currentPosition.longitude,
                    ),
                  ),
                  onMapCreated: _onMapCreated,
                  markers: _mapMarkers,
                  onLongPress: _setMarker,
                  polygons: _mapPolygons,
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    color: Colors.white,
                    child: TextFormField(
                      controller: _addressController,
                      onFieldSubmitted: (value) async {
                        var place = await _getAddress(value);
                        showModalBottomSheet(
                          context: context,
                          builder: (builder) {
                            return Container(
                              height: MediaQuery.of(context).size.height / 8,
                              child: Center(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) => Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Center(
                                      child: Text("${place[index]}"),
                                    ),
                                  ),
                                  separatorBuilder: (context, index) =>
                                      Divider(),
                                  itemCount: place.length,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search address',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: Stack(
              children: <Widget>[
                Align(
                  alignment: Alignment.bottomRight,
                  child: FloatingActionButton(
                    onPressed: () {
                      Share.share("$_currentPosition",
                          subject: "Aqui me encuentro");
                    },
                    child: Icon(Icons.share),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FloatingActionButton(
                    onPressed: () {
                      _seePolygons = !_seePolygons;
                      _createPolygons();
                    },
                    child: Icon(Icons.linear_scale),
                  ),
                ),
                Align(
                  alignment: Alignment(-0.8, 1),
                  child: FloatingActionButton(
                    onPressed: () {
                      _mapController.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: LatLng(
                              _currentPosition.latitude,
                              _currentPosition.longitude,
                            ),
                            zoom: 18.0,
                          ),
                        ),
                      );
                    },
                    child: Icon(Icons.center_focus_strong),
                  ),
                ),
              ],
            ),
          );
        } else {
          Scaffold(
            body: Center(
              child: Text("Se ha producido un error"),
            ),
          );
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  void _onMapCreated(controller) {
    setState(() {
      _mapController = controller;
    });
  }

  void _setMarker(LatLng coord) async {
    // get address
    String _markerAddress = await _getGeocodingAddress(
      Position(
        latitude: coord.latitude,
        longitude: coord.longitude,
      ),
    );

    // add marker
    setState(() {
      _mapMarkers.add(
        Marker(
            markerId: MarkerId(coord.toString()),
            position: coord,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            onTap: () {
              showModalBottomSheet(
                  context: context,
                  builder: (builder) {
                    return Container(
                      height: MediaQuery.of(context).size.height / 8,
                      child: Center(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(coord.toString()),
                          Text(_markerAddress),
                        ],
                      )),
                    );
                  });
            }),
      );
    });
  }

  Future<void> _getCurrentPosition() async {
    // verify permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    // get current position
    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium);

    // get address
    String _currentAddress = await _getGeocodingAddress(_currentPosition);

    // add marker
    _mapMarkers.add(
      Marker(
        markerId: MarkerId(_currentPosition.toString()),
        position: LatLng(_currentPosition.latitude, _currentPosition.longitude),
        infoWindow: InfoWindow(
          title: _currentPosition.toString(),
          snippet: _currentAddress,
        ),
      ),
    );

    // move camera
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition.latitude,
            _currentPosition.longitude,
          ),
          zoom: 15.0,
        ),
      ),
    );
  }

  Future<String> _getGeocodingAddress(Position position) async {
    // geocoding
    var places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (places != null && places.isNotEmpty) {
      final Placemark place = places.first;
      return "${place.thoroughfare}, ${place.locality}";
    }
    return "No address available";
  }

  Future<List<String>> _getAddress(String address) async {
    try {
      List<Address> addresses =
          await Geocoder.local.findAddressesFromQuery(address);
      List<String> addressLines = addresses.map((e) => e.addressLine).toList();
      return addressLines;
    } catch (e) {
      print(e);
      List<String> list = ['No address was found'];
      return list;
    }
  }

  void _createPolygons() {
    List<LatLng> polygonLatLngs = List<LatLng>();
    _mapPolygons = Set();
    if (_seePolygons) {
      for (int i = 0; i < _mapMarkers.length; i++) {
        polygonLatLngs.add(_mapMarkers.elementAt(i).position);
      }
      _mapPolygons.add(new Polygon(
        polygonId: PolygonId('Markers'),
        points: polygonLatLngs,
        strokeWidth: 2,
        strokeColor: Colors.yellow,
        fillColor: Colors.yellow.withOpacity(0.15),
      ));
    } else {
      setState(() {});
      return;
    }
    setState(() {});
  }
}
