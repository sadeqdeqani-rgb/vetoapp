import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        _country == null &&
        state.countries.isNotEmpty &&
        state.provinces.isEmpty;
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
      decoration: InputDecoration(labelText: label),
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
    return AuthScaffold(
      maxWidth: 560,
      onBack: () => context.pop(),
      child: BlocListener<RegistrationCubit, RegistrationState>(
        listener: (context, state) {
          if (state is RegistrationGeographyLoaded) {
            _onGeographyLoaded(state);
          } else if (state is RegistrationError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: AuthFormCard(
          title: 'ثبت نام',
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                onChanged: (value) => setState(() => _locality = value),
              ),
              const SizedBox(height: 24),
              AuthActionButton(
                label: 'بعدی',
                onPressed: _canContinue ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
