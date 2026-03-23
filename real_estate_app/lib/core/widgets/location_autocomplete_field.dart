// lib/core/widgets/location_autocomplete_field.dart
//
// Shared location input with Photon autocomplete suggestions and GPS button.
// Works on web, Android and iOS.

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/location_utils.dart';

/// A text field that shows Photon autocomplete suggestions as the user types,
/// with a GPS button to auto-detect current location.
///
/// [clearOnSelect] = true  → tag mode: clears field after selection (notification filter)
/// [clearOnSelect] = false → normal mode: fills field with displayName (filter/create)
class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? labelText;
  final String? Function(String?)? validator;
  final void Function(String name, String displayName) onSelected;

  /// Called with the lat/lng of the selected place (from Photon geometry or GPS).
  /// Only fired when coordinates are available.
  final void Function(double lat, double lng)? onCoordinatesSelected;

  /// true  → tag input: clears the field after the user selects a suggestion
  /// false → regular input: fills the field with the selected displayName
  final bool clearOnSelect;

  const LocationAutocompleteField({
    super.key,
    this.controller,
    required this.hintText,
    this.labelText,
    this.validator,
    required this.onSelected,
    this.onCoordinatesSelected,
    this.clearOnSelect = false,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField> {
  late final TextEditingController _ctrl;
  bool _ownsController = false;

  List<PhotonPlace> _suggestions = [];
  bool _isSearching    = false;
  bool _isDetectingGps = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = TextEditingController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      if (_suggestions.isNotEmpty || _isSearching) {
        setState(() { _suggestions = []; _isSearching = false; });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await photonSearch(value.trim());
      if (mounted) {
        setState(() { _suggestions = results; _isSearching = false; });
      }
    });
  }

  void _selectSuggestion(PhotonPlace place) {
    _debounce?.cancel();
    setState(() => _suggestions = []);
    if (widget.clearOnSelect) {
      _ctrl.clear();
    } else {
      _ctrl.text = place.displayName;
      _ctrl.selection =
          TextSelection.collapsed(offset: _ctrl.text.length);
    }
    widget.onSelected(place.name, place.displayName);
    if (place.latitude != null && place.longitude != null) {
      widget.onCoordinatesSelected?.call(place.latitude!, place.longitude!);
    }
  }

  Future<void> _detectGps() async {
    _debounce?.cancel();
    setState(() { _isDetectingGps = true; _suggestions = []; });
    final result = await detectCurrentLocationFull();
    if (!mounted) return;
    setState(() => _isDetectingGps = false);
    if (result.name != null) {
      if (!widget.clearOnSelect) {
        _ctrl.text = result.name!;
        _ctrl.selection =
            TextSelection.collapsed(offset: _ctrl.text.length);
      }
      widget.onSelected(result.name!, result.name!);
    }
    if (result.latitude != null && result.longitude != null) {
      widget.onCoordinatesSelected?.call(result.latitude!, result.longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.words,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.location_on),
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: _isDetectingGps
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location_rounded),
                    tooltip: 'Use my current location',
                    onPressed: _detectGps,
                  ),
          ),
          onChanged: _onChanged,
          onFieldSubmitted: (v) {
            final trimmed = v.trim();
            if (trimmed.isNotEmpty) {
              setState(() => _suggestions = []);
              if (widget.clearOnSelect) _ctrl.clear();
              widget.onSelected(trimmed, trimmed);
            }
          },
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 2),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 18),
                  title: Text(
                    place.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: place.context.isNotEmpty
                      ? Text(place.context,
                          style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () => _selectSuggestion(place),
                );
              },
            ),
          ),
      ],
    );
  }
}
