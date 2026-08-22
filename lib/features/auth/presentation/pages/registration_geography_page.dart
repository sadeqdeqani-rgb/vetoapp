import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../domain/entities/geographical_area.dart';
import '../cubit/registration_cubit.dart';

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
  List<GeographicalArea> _countries = const [];
  List<GeographicalArea> _provinces = const [];
  List<GeographicalArea> _counties = const [];
  List<GeographicalArea> _localities = const [];

  GeographicalArea? _country;
  GeographicalArea? _province;
  GeographicalArea? _county;
  GeographicalArea? _locality;

  bool get _canContinue =>
      _country != null &&
      _province != null &&
      _county != null &&
      _locality != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RegistrationCubit>().loadChildren(
          level: RegistrationLevel.country,
        );
      }
    });
  }

  void _onGeographyLoaded(RegistrationGeographyLoaded state) {
    final shouldLoadProvinces =
        _country == null && state.countries.isNotEmpty && state.provinces.isEmpty;
    setState(() {
      _countries = state.countries;
      _provinces = state.provinces;
      _counties = state.counties;
      _localities = state.localities;
      _country ??= _countries.isEmpty ? null : _countries.first;
    });
    if (shouldLoadProvinces && _country != null) {
      context.read<RegistrationCubit>().loadChildren(
        parentId: _country!.id,
        level: RegistrationLevel.province,
      );
    }
  }

  void _selectProvince(GeographicalArea? value) {
    setState(() {
      _province = value;
      _county = null;
      _locality = null;
      _counties = [];
      _localities = [];
    });
    if (value == null) return;
    context.read<RegistrationCubit>().loadChildren(
      parentId: value.id,
      level: RegistrationLevel.county,
    );
  }

  void _selectCounty(GeographicalArea? value) {
    setState(() {
      _county = value;
      _locality = null;
      _localities = [];
    });
    if (value == null) return;
    context.read<RegistrationCubit>().loadChildren(
      parentId: value.id,
      level: RegistrationLevel.locality,
    );
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
    required GeographicalArea? value,
    required List<GeographicalArea> items,
    required ValueChanged<GeographicalArea?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<GeographicalArea>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
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
                  child: BlocListener<RegistrationCubit, RegistrationState>(
                    listener: (context, state) {
                      if (state is RegistrationGeographyLoaded) {
                        _onGeographyLoaded(state);
                      } else if (state is RegistrationError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.message)),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      const AuthBrandHeader(),
                      const SizedBox(height: AppTheme.authLogoGap),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                            decoration: BoxDecoration(
                              color: AppTheme.surface.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.shadow.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
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
                                      (value) =>
                                          setState(() => _locality = value),
                                ),
                                const SizedBox(height: 24),
                                AuthActionButton(
                                  label: 'بعدی',
                                  onPressed: _canContinue ? _continue : null,
                                ),
                              ],
                            ),
                          ),
                          const Positioned(
                            top: -29,
                            left: 20,
                            right: 20,
                            child: FloatingAuthTitle(
                              title: 'ثبت نام در وِتواَپ',
                            ),
                          ),
                        ],
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
