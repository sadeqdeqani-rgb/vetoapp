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
    required this.draftId,
    required this.telegramIdentityId,
  });

  final String phoneNumber;
  final String nationalCode;
  final String draftId;
  final String telegramIdentityId;

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
        'draftId': widget.draftId,
        'telegramIdentityId': widget.telegramIdentityId,
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
    return _SearchableAreaSelector(
      label: label,
      value: value,
      items: items,
      enabled: enabled,
      onSelected: onChanged,
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
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
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
              _SelectedGeographySummary(
                country: _country,
                province: _province,
                county: _county,
                locality: _locality,
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

class _SelectedGeographySummary extends StatelessWidget {
  const _SelectedGeographySummary({
    required this.country,
    required this.province,
    required this.county,
    required this.locality,
  });

  final GeographicalArea? country;
  final GeographicalArea? province;
  final GeographicalArea? county;
  final GeographicalArea? locality;

  @override
  Widget build(BuildContext context) {
    final values = <String, GeographicalArea?>{
      'کشور': country,
      'استان': province,
      'شهرستان': county,
      'شهر / روستا': locality,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('مسیر انتخاب‌شده',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...values.entries.map((entry) {
            final area = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text('${entry.key}:')),
                  Expanded(
                    child: Text(
                      area?.name ?? 'انتخاب نشده',
                      style: TextStyle(
                        fontWeight:
                            area == null ? FontWeight.normal : FontWeight.w600,
                        color: area == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    area == null
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle,
                    size: 18,
                    color: area == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SearchableAreaSelector extends StatelessWidget {
  const _SearchableAreaSelector({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final GeographicalArea? value;
  final List<GeographicalArea> items;
  final bool enabled;
  final ValueChanged<GeographicalArea?> onSelected;

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .trim();

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || items.isEmpty) return;
    final selected = await showModalBottomSheet<GeographicalArea>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AreaSearchSheet(
        label: label,
        items: items,
        selected: value,
        normalize: _normalize,
      ),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled && items.isNotEmpty ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.search),
          helperText: items.isEmpty && enabled ? 'فهرست آماده نیست' : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value?.name ?? 'برای جست‌وجو و انتخاب لمس کنید',
                style: TextStyle(
                  color: value == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (value != null)
              Icon(Icons.check_circle,
                  size: 18, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _AreaSearchSheet extends StatefulWidget {
  const _AreaSearchSheet({
    required this.label,
    required this.items,
    required this.selected,
    required this.normalize,
  });

  final String label;
  final List<GeographicalArea> items;
  final GeographicalArea? selected;
  final String Function(String) normalize;

  @override
  State<_AreaSearchSheet> createState() => _AreaSearchSheetState();
}

class _AreaSearchSheetState extends State<_AreaSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.normalize(_query);
    final filtered = widget.items
        .where((area) => widget.normalize(area.name).contains(query))
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'جست‌وجو در فهرست',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'پاک کردن جست‌وجو',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (text) => setState(() => _query = text),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('موردی پیدا نشد.'))
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final area = filtered[index];
                          final isSelected = area.id == widget.selected?.id;
                          return ListTile(
                            title: Text(area.name),
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary)
                                : null,
                            onTap: () => Navigator.of(context).pop(area),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
