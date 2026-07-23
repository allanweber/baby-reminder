import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line-drawn icons ported 1:1 from the inline SVGs in the prototype
/// (`Baby Feed Tracker.dc.html`) — gear, house, calendar, feeding bottle.
class AppIcons {
  static String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  static Widget gear({double size = 19, required Color color}) {
    final stroke = _hex(color);
    return SvgPicture.string(
      '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$stroke" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 15a3 3 0 100-6 3 3 0 000 6z"></path>
  <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 11-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 11-4 0v-.09a1.65 1.65 0 00-1.08-1.51 1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 11-2.83-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 110-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 114 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 112.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9c.14.59.63 1.04 1.51 1H21a2 2 0 110 4h-.09a1.65 1.65 0 00-1.51 1z"></path>
</svg>
''',
      width: size,
      height: size,
    );
  }

  static Widget house({double size = 20, required Color color}) {
    final stroke = _hex(color);
    return SvgPicture.string(
      '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$stroke" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11l9-8 9 8"></path><path d="M5 10v10a1 1 0 001 1h4a1 1 0 001-1v-4a1 1 0 011-1h0a1 1 0 011 1v4a1 1 0 001 1h4a1 1 0 001-1V10"></path></svg>
''',
      width: size,
      height: size,
    );
  }

  static Widget calendar({double size = 20, required Color color}) {
    final stroke = _hex(color);
    return SvgPicture.string(
      '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$stroke" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="17" rx="2"></rect><path d="M3 9h18"></path><path d="M8 2v4"></path><path d="M16 2v4"></path><path d="M8 13h.01"></path><path d="M12 13h.01"></path><path d="M16 13h.01"></path><path d="M8 17h.01"></path><path d="M12 17h.01"></path></svg>
''',
      width: size,
      height: size,
    );
  }

  static Widget bottle({double size = 26, required Color color}) {
    final stroke = _hex(color);
    return SvgPicture.string(
      '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$stroke" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M9 2h4"></path>
  <path d="M10 2v3.2c0 .4-.15.78-.42 1.08L8.2 7.9A2 2 0 007.5 9.4V20a2 2 0 002 2h5a2 2 0 002-2V9.4a2 2 0 00-.7-1.5L14.42 6.3a1.6 1.6 0 01-.42-1.08V2"></path>
  <path d="M7.5 13h9"></path>
</svg>
''',
      width: size,
      height: size,
    );
  }
}
