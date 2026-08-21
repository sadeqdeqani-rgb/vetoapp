import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/geographical_area_model.dart';

class RegistrationGeographyPage extends StatefulWidget {
  const RegistrationGeographyPage({
    super.key,
    required this.phoneNumber,
    required this.nationalCode,
  });

  final String phoneNumber;
  final String nationalCode;

  @override
  State<RegistrationGeographyPage> createState() =>
      _RegistrationGeographyPageState();
}

class _RegistrationGeographyPageState extends State<RegistrationGeographyPage> {
  static const _iran = GeographicalAreaModel(
    id: 1,
    name: 'ایران',
    type: 'country',
  );
  static const _fars = GeographicalAreaModel(
    id: 11,
    parentId: 1,
    name: 'فارس',
    type: 'province',
  );
  static const _isfahan = GeographicalAreaModel(
    id: 12,
    parentId: 1,
    name: 'اصفهان',
    type: 'province',
  );
  static const _yazd = GeographicalAreaModel(
    id: 13,
    parentId: 1,
    name: 'یزد',
    type: 'province',
  );
  static const _noorabadMamsani = GeographicalAreaModel(
    id: 111,
    parentId: 11,
    name: 'نورآباد ممسنی',
    type: 'county',
  );
  static const _shahreza = GeographicalAreaModel(
    id: 121,
    parentId: 12,
    name: 'شهرضا',
    type: 'county',
  );
  static const _naeimAbad = GeographicalAreaModel(
    id: 131,
    parentId: 13,
    name: 'نعیم آباد',
    type: 'county',
  );
  static const _dehgahMahmoudi = GeographicalAreaModel(
    id: 1111,
    parentId: 111,
    name: 'دهگپ محمودی',
    type: 'locality',
  );
  static const _doulghari = GeographicalAreaModel(
    id: 1211,
    parentId: 121,
    name: 'دولقری',
    type: 'locality',
  );
  static const _takhtDoTabaghe = GeographicalAreaModel(
    id: 1311,
    parentId: 131,
    name: 'تخت دو طبقه',
    type: 'locality',
  );

  final List<GeographicalAreaModel> _countries = const [_iran];
  final List<GeographicalAreaModel> _provinces = const [_fars, _isfahan, _yazd];
  List<GeographicalAreaModel> _counties = const [];
  List<GeographicalAreaModel> _localities = const [];

  GeographicalAreaModel? _country;
  GeographicalAreaModel? _province;
  GeographicalAreaModel? _county;
  GeographicalAreaModel? _locality;

  @override
  void initState() {
    super.initState();
    _country = _iran;
  }

  void _selectProvince(GeographicalAreaModel? value) {
    setState(() {
      _province = value;
      _county = null;
      _locality = null;
      _counties = [];
      _localities = [];
    });
    if (value == null) return;
    setState(() {
      _counties = switch (value.id) {
        11 => const [_noorabadMamsani],
        12 => const [_shahreza],
        13 => const [_naeimAbad],
        _ => const [],
      };
    });
  }

  void _selectCounty(GeographicalAreaModel? value) {
    setState(() {
      _county = value;
      _locality = null;
      _localities = [];
    });
    if (value == null) return;
    setState(() {
      _localities = switch (value.id) {
        111 => const [_dehgahMahmoudi],
        121 => const [_doulghari],
        131 => const [_takhtDoTabaghe],
        _ => const [],
      };
    });
  }

  void _continue() {
    if (_country == null ||
        _province == null ||
        _county == null ||
        _locality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً همهٔ سطوح حوزه را انتخاب کنید.')),
      );
      return;
    }

    context.push(
      '/register/password',
      extra: <String, dynamic>{
        'phoneNumber': widget.phoneNumber,
        'nationalCode': widget.nationalCode,
        'countryId': _country!.id,
        'provinceId': _province!.id,
        'countyId': _county!.id,
        'localityId': _locality!.id,
      },
    );
  }

  Widget _dropdown({
    required String label,
    required GeographicalAreaModel? value,
    required List<GeographicalAreaModel> items,
    required ValueChanged<GeographicalAreaModel?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<GeographicalAreaModel>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      items:
          items
              .map(
                (item) => DropdownMenuItem(value: item, child: Text(item.name)),
              )
              .toList(),
      onChanged: !enabled || items.isEmpty ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.pageBackground,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          AppTheme.appLogo,
                          width: 112,
                          height: 112,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Text(
                            'ثبت نام در وتو اپ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'حوزهٔ جغرافیایی کاربری خود را با دقت انتخاب کنید.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, height: 1.8),
                        ),
                        const SizedBox(height: 20),
                        _dropdown(
                          label: 'انتخاب کشور',
                          value: _country,
                          items: _countries,
                          onChanged: (_) {},
                          enabled: false,
                        ),
                        const SizedBox(height: 18),
                        _dropdown(
                          label: 'انتخاب استان',
                          value: _province,
                          items: _provinces,
                          onChanged: _selectProvince,
                        ),
                        const SizedBox(height: 18),
                        _dropdown(
                          label: 'انتخاب شهرستان',
                          value: _county,
                          items: _counties,
                          onChanged: _selectCounty,
                        ),
                        const SizedBox(height: 18),
                        _dropdown(
                          label: 'انتخاب شهر / روستا',
                          value: _locality,
                          items: _localities,
                          onChanged:
                              (value) => setState(() => _locality = value),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _continue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              'بعدی',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
