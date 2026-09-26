import 'package:latlong2/latlong.dart';

class HarvesthubMapConfig {
  /* Fast, reliable OpenStreetMap standard tiles (100% free, no API key required) */
  static const String osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /* Alternative Humanitarian OpenStreetMap tiles */
  static const String hotOsmUrl =
      'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';

  /* Default center when user location is not yet known (Da Lat, Vietnam) */
  static const LatLng defaultLocation = LatLng(11.9404, 108.4583);
  static const double defaultZoom = 13.0;
  static const double detailZoom = 15.0;
}
