import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing_user_app/features/location/domain/models/place_details_model.dart';
import 'package:ride_sharing_user_app/features/location/domain/models/prediction_model.dart';
import 'package:ride_sharing_user_app/features/location/domain/models/zone_response.dart';
import 'package:ride_sharing_user_app/features/location/domain/services/location_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_dialog_widget.dart';
import 'package:flutter/foundation.dart';

enum LocationType {
  from,
  to,
  extraOne,
  extraTwo,
  location,
  accessLocation,
  senderLocation,
  receiverLocation
}

class LocationController extends GetxController implements GetxService {
  final LocationServiceInterface locationServiceInterface;
  LocationController({required this.locationServiceInterface});

  Position _position = Position(
      longitude: 0,
      latitude: 0,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      heading: 1,
      speed: 1,
      speedAccuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1);
  Position _pickPosition = Position(
      longitude: 0,
      latitude: 0,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      heading: 1,
      speed: 1,
      speedAccuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1);
  Address? fromAddress;
  Address? toAddress;
  Address? extraRouteAddress;
  Address? extraRouteTwoAddress;
  Address? parcelSenderAddress;
  Address? parcelReceiverAddress;
  bool _loading = false;
  String _address = '';
  String _pickAddress = '';
  List<AddressModel>? _addressList;
  bool _isLoading = false;
  bool _inZone = false;
  String? _zoneID;
  bool _buttonDisabled = true;
  bool _changeAddress = true;
  GoogleMapController? mapController;
  List<PredictionModel> _predictionList = [];
  bool _updateAddAddressData = true;
  LatLng _initialPosition = const LatLng(23.83721, 90.363715);
  bool addEntrance = false;
  int currentExtraRoute = 0;
  bool extraOneRoute = false;
  bool extraTwoRoute = false;
  bool resultShow = false;
  bool picking = false;
  double topPosition = 120;
  LocationType locationType = LocationType.from;

  // Bottom navigation bar visibility control
  bool _showBottomNavigationBar = false;
  double _lastScrollPosition = 0.0;
  ScrollController? _currentScrollController;
  ValueNotifier<bool> bottomNavVisibility = ValueNotifier<bool>(false);

  List<PredictionModel> get predictionList => _predictionList;
  bool get isLoading => _isLoading;
  bool get loading => _loading;
  Position get position => _position;
  Position get pickPosition => _pickPosition;
  String get address => _address;
  String get pickAddress => _pickAddress;
  List<AddressModel>? get addressList => _addressList;
  bool get inZone => _inZone;
  String? get zoneID => _zoneID;
  bool get buttonDisabled => _buttonDisabled;
  LatLng get initialPosition => _initialPosition;
  bool get showBottomNavigationBar => _showBottomNavigationBar;
  List<Map<String, dynamic>> _breakpoints = [];

  List<Map<String, dynamic>> get breakpoints => _breakpoints;

  final TextEditingController locationController = TextEditingController();
  final TextEditingController entranceController = TextEditingController();
  final TextEditingController pickupLocationController =
      TextEditingController();
  final TextEditingController addPassengersController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController destinationLocationController =
      TextEditingController();
  final TextEditingController extraRouteOneController = TextEditingController();
  final TextEditingController extraRouteTwoController = TextEditingController();
  final FocusNode entranceNode = FocusNode();

  void initAddLocationData() {
    addEntrance = false;
    extraTwoRoute = false;
    extraOneRoute = false;
    resultShow = false;
    currentExtraRoute = 0;
    _isLoading = false;
    _loading = false;
    _pickPosition = Position(
        longitude: 0,
        latitude: 0,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1);
  }

  void updateBreakpoint(int index, String address, Position position) {
    if (index < _breakpoints.length) {
      _breakpoints[index] = {
        'address': address,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
      update();
    }
  }

  void initializeStaticBreakpoints() {
    _breakpoints = [
      {
        'address':
            'Makram Ebeid, Al Manteqah Ath Thamenah, Nasr City, Cairo Governorate 4441564',
        'latitude': 30.0444,
        'longitude': 31.2357,
      },
      {
        'address':
            'Makram Ebeid, Al Manteqah Ath Thamenah, Nasr City, Cairo Governorate 4441564',
        'latitude': 30.0594,
        'longitude': 31.2234,
      },
    ];
    update();
  }

  void removeBreakpoint(int index) {
    if (index < _breakpoints.length) {
      _breakpoints.removeAt(index);
      update();
    }
  }

  Future<String?> getPlaceWithLanLng({
    required double lat,
    required double lng,
  }) async {
    try {
      String baserUrl =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${AppConstants.mapKey}";
      final response = await http.get(Uri.parse(baserUrl));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        _address = data['results'][0]['formatted_address'];
        pickupLocationController.text = _address;
        fromAddress = Address(latitude: lat, longitude: lng, address: _address);
        update();
        print(
            '================================================================>${fromAddress!.address}');
      }
      return response.toString();
    } catch (failure) {
      print(failure);
    }
    return null;
  }

  void initTextControllers() {
    print(
        'LocationController: initTextControllers() called - clearing pickup location');
    locationController.clear();
    _pickAddress = '';
    pickupLocationController.text = '';
    destinationLocationController.text = '';
    extraRouteOneController.text = '';
    extraRouteTwoController.text = '';
    entranceController.text = '';
  }

  void initParcelData() {
    parcelSenderAddress = null;
    parcelReceiverAddress = null;
  }

  void setAddEntrance() {
    addEntrance = !addEntrance;
    update();
  }

  void setPickUp(Address? address) {
    print(
        'LocationController: setPickUp() called with address: ${address?.address}');
    pickupLocationController.text = address?.address ?? '';
    fromAddress = address;
  }

  void setDestination(Address? address) {
    destinationLocationController.text = address?.address ?? '';
    toAddress = address;
  }

  @override
  void onInit() {
    super.onInit();
    // Remove automatic getCurrentLocation call to prevent conflicts
    // Location will be obtained manually in screens that need it
  }

  void setExtraRoute({bool remove = false}) {
    if (remove) {
      currentExtraRoute = currentExtraRoute - 1;
      if (currentExtraRoute == 1) {
        extraTwoRoute = false;
      } else {
        extraOneRoute = false;
      }
    } else {
      if (currentExtraRoute < 2) {
        currentExtraRoute = currentExtraRoute + 1;

        if (currentExtraRoute == 1) {
          extraOneRoute = true;
        }
        if (currentExtraRoute == 2) {
          extraTwoRoute = true;
        }
      }
    }
    if (kDebugMode) {
      print('=======extra===>$currentExtraRoute');
    }
    update();
  }

  StreamSubscription? _locationSubscription;
  Future<Address?> getCurrentLocation(
      {bool isAnimate = true,
      GoogleMapController? mapController,
      LocationType type = LocationType.from}) async {
    print('LocationController: getCurrentLocation() called with type: $type');
    bool isSuccess = await checkPermission(() {});
    Address? addressModel;
    if (isSuccess) {
      try {
        if (_locationSubscription != null) {
          _locationSubscription!.cancel();
        }

        Position newLocalData = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        _position = newLocalData;
        _initialPosition = LatLng(_position.latitude, _position.longitude);
        if (isAnimate && mapController != null) {
          mapController.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: _initialPosition, zoom: 15)));
        }
        if (type == LocationType.from) {
          _pickPosition = Position(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: DateTime.now(),
              heading: 1,
              accuracy: 1,
              altitude: 1,
              speedAccuracy: 1,
              speed: 1,
              altitudeAccuracy: 1,
              headingAccuracy: 1);
          ZoneResponseModel responseModel = await getZone(
              _position.latitude.toString(), _position.longitude.toString());
          String address =
              await initAddressAddressFromGeocode(_initialPosition);

          addressModel = Address(
            latitude: newLocalData.latitude,
            longitude: newLocalData.longitude,
            address: address,
            zoneId: responseModel.zoneId,
          );
          await saveUserAddress(addressModel);
        }

        _locationSubscription =
            Geolocator.getPositionStream().listen((newLocalData) {
          if (mapController != null) {
            Get.find<MapController>().updateMarkerAndCircle(
                latLng: LatLng(newLocalData.latitude, newLocalData.longitude));
          }
        });
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      if (mapController != null) {
        mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
              target:
                  LatLng(_initialPosition.latitude, _initialPosition.longitude),
              zoom: 16),
        ));
      }

      update();
    }
    return addressModel;
  }

  Future<LatLng?> getCurrentPosition(
      {GoogleMapController? mapController}) async {
    bool isSuccess = await checkPermission(() {});
    LatLng? latLng;
    if (isSuccess) {
      try {
        Position newLocalData = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        latLng = LatLng(newLocalData.latitude, newLocalData.longitude);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }

      if (mapController != null && latLng != null) {
        mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
              target: LatLng(latLng.latitude, latLng.longitude), zoom: 16),
        ));
      }

      update();
    }
    return latLng;
  }

  bool selectLocation = false;
  Future<ZoneResponseModel> getZone(String lat, String long) async {
    _isLoading = true;
    update();
    ZoneResponseModel responseModel;
    Response response = await locationServiceInterface.getZone(lat, long);
    if (response.statusCode == 200 &&
        response.body['data'] != null &&
        response.body['data']['id'] != null) {
      _zoneID = response.body['data']['id'].toString();
      // Get.find<ApiClient>().updateHeader(Get.find<ApiClient>().token, null,zoneId: _zoneID);
      _inZone = true;
      responseModel = ZoneResponseModel(true, '', _zoneID);
    } else {
      _inZone = false;
      responseModel = ZoneResponseModel(false, response.statusText, null);
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<void> saveUserAddress(Address? address) async {
    locationServiceInterface.saveUserAddress(address);
  }

  Address? getUserAddress() {
    Address? address;
    if (locationServiceInterface.getUserAddress() != null) {
      address = Address.fromJson(
          jsonDecode(locationServiceInterface.getUserAddress()!));
    }
    return address;
  }

  Future<String> initAddressAddressFromGeocode(LatLng latLng) async {
    Response response =
        await locationServiceInterface.getAddressFromGeocode(latLng);
    if (response.statusCode == 200) {
      _address =
          response.body['data']['results'][0]['formatted_address'].toString();
      print(
          'LocationController: initAddressAddressFromGeocode - Setting pickup controller to: $_address');
      pickupLocationController.text = _address;
      fromAddress = Address(
          latitude: latLng.latitude,
          longitude: latLng.longitude,
          address: _address);
    } else {
      showCustomSnackBar(
          response.body['errors'][0]['message'] ?? response.bodyString);
    }
    update();
    return _address;
  }

  Future<String> getAddressFromGeocode(LatLng latLng) async {
    Response response =
        await locationServiceInterface.getAddressFromGeocode(latLng);
    if (response.statusCode == 200) {
      _address =
          response.body['data']['results'][0]['formatted_address'].toString();
    } else {
      showCustomSnackBar(
          response.body['errors'][0]['message'] ?? response.bodyString);
    }
    update();
    return _address;
  }

  Future<List<PredictionModel>> searchLocation(
      BuildContext context, String text,
      {LocationType type = LocationType.from, bool fromMap = false}) async {
    locationType = type;
    if (!fromMap) {
      positionSetForDialog();
      update();
    }

    if (text.isNotEmpty) {
      if (!fromMap) {
        setSearchResultShowHide(show: true);
      }

      Response response = await locationServiceInterface.searchLocation(text);
      if (response.statusCode == 200) {
        _predictionList = [];
        response.body['data']['predictions'].forEach((prediction) =>
            _predictionList.add(PredictionModel.fromJson(prediction)));
        update();
      } else {
        //customSnackBar(response.body['message'] ?? response.bodyString,isError:false);
      }
    } else {
      if (!fromMap) {
        setSearchResultShowHide(show: false);
      }
    }
    return _predictionList;
  }

  void positionSetForDialog() {
    if (locationType == LocationType.from) {
      topPosition = 85;
    } else if (locationType == LocationType.extraOne) {
      topPosition = 165;
    } else if (locationType == LocationType.extraTwo) {
      topPosition = 245;
    } else if (locationType == LocationType.to &&
        extraOneRoute &&
        extraTwoRoute) {
      topPosition = 325;
    } else if (locationType == LocationType.to && extraOneRoute) {
      topPosition = 245;
    } else if (locationType == LocationType.to) {
      topPosition = 165;
    }
  }

  void updatePosition(LatLng? positionLatLng, bool fromAddressScreen,
      LocationType? type) async {
    if (_updateAddAddressData && positionLatLng != null) {
      _loading = true;
      update();
      try {
        if (fromAddressScreen) {
          type == LocationType.from
              ? fromAddress
              : type == LocationType.to
                  ? toAddress
                  : type == LocationType.extraOne
                      ? extraRouteOneController.text
                      : type == LocationType.extraTwo
                          ? extraRouteTwoController.text
                          : _position = Position(
                              latitude: positionLatLng.latitude,
                              longitude: positionLatLng.longitude,
                              timestamp: DateTime.now(),
                              heading: 1,
                              accuracy: 1,
                              altitude: 1,
                              speedAccuracy: 1,
                              speed: 1,
                              altitudeAccuracy: 1,
                              headingAccuracy: 1);
        } else {
          _pickPosition = Position(
              latitude: positionLatLng.latitude,
              longitude: positionLatLng.longitude,
              timestamp: DateTime.now(),
              heading: 1,
              accuracy: 1,
              altitude: 1,
              speedAccuracy: 1,
              speed: 1,
              altitudeAccuracy: 1,
              headingAccuracy: 1);
        }
        ZoneResponseModel responseModel = await getZone(
            positionLatLng.latitude.toString(),
            positionLatLng.longitude.toString());
        if (responseModel.isSuccess) {
          _buttonDisabled = false;
        }
        if (_changeAddress) {
          String addressFromGeocode = await getAddressFromGeocode(
              LatLng(positionLatLng.latitude, positionLatLng.longitude));
          fromAddressScreen
              ? _address = addressFromGeocode
              : _pickAddress = addressFromGeocode;

          locationController.text = address;
        } else {
          _changeAddress = true;
        }
        // ignore: empty_catches
      } catch (e) {}
    } else {
      _updateAddAddressData = true;
    }
    _loading = false;
    update();
  }

  Future<void> saveAddressAndNavigate(
      Address address, LocationType type) async {
    picking = true;
    update();

    setSearchResultShowHide(show: false);
    if (type == LocationType.accessLocation) {
      await saveUserAddress(address);
      Get.find<CategoryController>().getCategoryList();
      Get.find<BottomMenuController>().navigateToDashboard();
    } else {
      Get.back();
      if (type == LocationType.from) {
        pickupLocationController.text = address.address!;
        fromAddress = address;
      } else if (type == LocationType.to) {
        destinationLocationController.text = address.address!;
        toAddress = address;
      } else if (type == LocationType.extraOne) {
        extraRouteOneController.text = address.address!;
        extraRouteAddress = address;
      } else if (type == LocationType.extraTwo) {
        extraRouteTwoController.text = address.address!;
        extraRouteTwoAddress = address;
      } else if (type == LocationType.senderLocation) {
        Get.find<ParcelController>().senderAddressController.text =
            address.address!;
        parcelSenderAddress = address;
      } else if (type == LocationType.receiverLocation) {
        Get.find<ParcelController>().receiverAddressController.text =
            address.address!;
        parcelReceiverAddress = address;
      } else {
        _pickAddress = address.address!;
        _pickPosition = Position(
            latitude: address.latitude!,
            longitude: address.longitude!,
            timestamp: DateTime.now(),
            accuracy: 1,
            altitude: 1,
            heading: 1,
            speed: 1,
            speedAccuracy: 1,
            altitudeAccuracy: 1,
            headingAccuracy: 1);
      }
    }
    picking = false;
    update();
  }

  void setSenderAddress(Address? address) {
    Get.find<ParcelController>().senderAddressController.text =
        address?.address ?? '';
    parcelSenderAddress = address;
    update();
  }

  void setReceiverAddress(Address? address) {
    Get.find<ParcelController>().receiverAddressController.text =
        address?.address ?? '';
    parcelReceiverAddress = address;
    update();
  }

  void setSearchResultShowHide({bool show = false}) {
    resultShow = show;
    update();
  }

  bool selecting = false;
  Future<Address?> setLocation(
      String placeID, String address, GoogleMapController? mapController,
      {LocationType type = LocationType.from, bool fromSearch = false}) async {
    _loading = true;
    resultShow = false;
    selecting = true;
    update();
    LatLng latLng = const LatLng(0, 0);
    Address? selectedAddress;
    Response response = await locationServiceInterface.getPlaceDetails(placeID);
    if (response.statusCode == 200 && response.body['data']['status'] == 'OK') {
      PlaceDetailsModel placeDetails =
          PlaceDetailsModel.fromJson(response.body);
      latLng = LatLng(placeDetails.data!.result!.geometry!.location!.lat!,
          placeDetails.data!.result!.geometry!.location!.lng!);

      ZoneResponseModel zoneResponse = await getZone(
          latLng.latitude.toString(), latLng.longitude.toString());
      if (zoneResponse.zoneId != null) {
        _predictionList = [];
        if (fromSearch) {
          if (type == LocationType.from) {
            fromAddress = Address(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                address: address);
            pickupLocationController.text = address;
          } else if (type == LocationType.to) {
            toAddress = Address(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                address: address);
            destinationLocationController.text = address;
          } else if (type == LocationType.extraOne) {
            extraRouteAddress = Address(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                address: address);
            extraRouteOneController.text = address;
          } else if (type == LocationType.extraTwo) {
            extraRouteTwoAddress = Address(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                address: address);
            extraRouteTwoController.text = address;
          }
        }

        _pickPosition = Position(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            timestamp: DateTime.now(),
            accuracy: 1,
            altitude: 1,
            heading: 1,
            speed: 1,
            speedAccuracy: 1,
            altitudeAccuracy: 1,
            headingAccuracy: 1);
        _pickAddress = address;

        _changeAddress = false;
        if (mapController != null) {
          mapController.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16)));
        }
        selecting = false;
        _loading = false;
        update();
        selectedAddress = Address(
          latitude: pickPosition.latitude,
          longitude: pickPosition.longitude,
          addressLabel: 'others',
          address: pickAddress,
        );
      } else {
        selecting = false;
        showCustomSnackBar('service_not_available_in_this_area'.tr);
      }
    }
    selecting = false;
    return selectedAddress;
  }

  void disableButton() {
    _buttonDisabled = true;
    _inZone = true;
    update();
  }

  void setAddAddressData(LocationType type) {
    if (type == LocationType.from) {
      _position = _pickPosition;
      _address = _pickAddress;
      _updateAddAddressData = false;
    }

    update();
  }

  void setPickData(LocationType type) {
    if (type == LocationType.from) {
      _pickPosition = _position;
      _pickAddress = _address;
    }
  }

  Future<bool> checkPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(
          ConfirmationDialogWidget(
              description: 'you_denied_location_permission'.tr,
              onYesPressed: () async {
                Get.back();
                await Geolocator.openAppSettings();
              },
              icon: Images.logo),
          barrierDismissible: false);
    } else {
      onTap();
      return true;
    }
    return false;
  }

  /// Track scroll direction in draggable scroll sheet
  void trackScrollDirection(ScrollController scrollController) {
    // Remove previous listener if exists
    if (_currentScrollController != null) {
      _currentScrollController!.removeListener(_scrollListener);
    }

    _currentScrollController = scrollController;
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_currentScrollController == null) return;

    double currentScrollPosition = _currentScrollController!.offset;
    double scrollDifference = currentScrollPosition - _lastScrollPosition;

    // Only react to significant scroll movements to avoid jitter
    if (scrollDifference.abs() > 5) {
      if (scrollDifference > 0) {
        // Scrolling up (expanding the sheet) - hide bottom nav
        if (_showBottomNavigationBar) {
          _showBottomNavigationBar = false;
          update();
        }
      } else {
        // Scrolling down (collapsing the sheet) - show bottom nav
        if (!_showBottomNavigationBar) {
          _showBottomNavigationBar = true;
          update();
        }
      }

      _lastScrollPosition = currentScrollPosition;
    }
  }

  /// Manually set bottom navigation bar visibility
  void setBottomNavigationBarVisibility(bool show) {
    if (_showBottomNavigationBar != show) {
      _showBottomNavigationBar = show;
      update();
    }
  }

  /// Track draggable sheet size changes
  void trackDraggableSheetPosition(double currentSize) {
    // If sheet is collapsed (size <= 0.5), hide bottom nav (more map view)
    // If sheet is expanded (size > 0.5), show bottom nav (user is interacting with content)
    bool shouldShowBottomNav = currentSize > 0.5;

    if (_showBottomNavigationBar != shouldShowBottomNav) {
      _showBottomNavigationBar = shouldShowBottomNav;
      // Update ValueNotifier instead of calling update()
      bottomNavVisibility.value = shouldShowBottomNav;
    }
  }

  /// Setup draggable sheet listener safely
  void setupSheetListener(DraggableScrollableController controller) {
    controller.addListener(() {
      if (controller.isAttached) {
        trackDraggableSheetPosition(controller.size);
      }
    });
  }

  /// Initialize scroll tracking for draggable sheet
  void initializeScrollTracking() {
    _showBottomNavigationBar = true; // Start with bottom nav visible
    _lastScrollPosition = 0.0;
    bottomNavVisibility.value = true; // Initialize ValueNotifier to true
    // Remove any existing listener
    if (_currentScrollController != null) {
      _currentScrollController!.removeListener(_scrollListener);
      _currentScrollController = null;
    }
    // Don't call update() here to avoid setState during build
    // State changes will be handled by ValueNotifier
  }
}
