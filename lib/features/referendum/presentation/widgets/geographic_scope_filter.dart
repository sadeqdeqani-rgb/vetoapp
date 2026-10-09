import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/geographical_area.dart';
import '../../data/repositories/referendum_proposal_repository.dart';

class GeographicScopeSelection {
  const GeographicScopeSelection({
    this.country,
    this.province,
    this.county,
    this.locality,
  });

  final GeographicalArea? country;
  final GeographicalArea? province;
  final GeographicalArea? county;
  final GeographicalArea? locality;

  GeographicalArea? get deepest => locality ?? county ?? province ?? country;
}

class GeographicScopeFilter extends StatefulWidget {
  const GeographicScopeFilter({
    super.key,
    required this.onChanged,
    this.accent = AppTheme.primary,
  });

  final ValueChanged<GeographicScopeSelection> onChanged;
  final Color accent;

  @override
  State<GeographicScopeFilter> createState() => _GeographicScopeFilterState();
}

class _GeographicScopeFilterState extends State<GeographicScopeFilter> {
  final _repository = getIt<ReferendumProposalRepository>();
  GeographicalArea? _country;
  GeographicalArea? _province;
  GeographicalArea? _county;
  GeographicalArea? _locality;
  bool _loading = false;

  Future<void> _choose(String type) async {
    final parent = switch (type) {
      'province' => _country,
      'county' => _province,
      'locality' => _county,
      _ => null,
    };
    if (type != 'country' && parent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا حوزهٔ بالادستی را انتخاب کنید.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final items = await _repository.geographyChildren(
        parentId: parent?.id,
        childType: type,
      );
      if (!mounted) return;
      final value = await showModalBottomSheet<GeographicalArea>(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => _SearchableAreaSheet(
              title: _label(type),
              items: items,
              accent: widget.accent,
            ),
      );
      if (!mounted || value == null) return;
      setState(() {
        if (type == 'country') {
          _country = value;
          _province = _county = _locality = null;
        } else if (type == 'province') {
          _province = value;
          _county = _locality = null;
        } else if (type == 'county') {
          _county = value;
          _locality = null;
        } else if (type == 'locality') {
          _locality = value;
        }
      });
      widget.onChanged(
        GeographicScopeSelection(
          country: _country,
          province: _province,
          county: _county,
          locality: _locality,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(String type) => switch (type) {
    'country' => 'کشور',
    'province' => 'استان',
    'county' => 'شهرستان',
    _ => 'شهر یا روستا',
  };

  String _errorText(Object error) =>
      error is DioException
          ? 'دریافت فهرست حوزه‌ها از سرور انجام نشد.'
          : 'دریافت فهرست حوزه‌ها انجام نشد: $error';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_outlined, color: widget.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'فیلتر بر پایهٔ حوزهٔ جغرافیایی',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: widget.accent),
                  onPressed:
                      _loading
                          ? null
                          : () {
                            setState(
                              () =>
                                  _country =
                                      _province = _county = _locality = null,
                            );
                            widget.onChanged(const GeographicScopeSelection());
                          },
                  child: const Text('پاک‌کردن'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _picker('کشور', _country, () => _choose('country')),
            _picker('استان', _province, () => _choose('province')),
            _picker('شهرستان', _county, () => _choose('county')),
            _picker('شهر یا روستا', _locality, () => _choose('locality')),
          ],
        ),
      ),
    );
  }

  Widget _picker(String label, GeographicalArea? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: _loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerRight,
          foregroundColor: widget.accent,
          side: BorderSide(color: widget.accent.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value?.name ?? 'انتخاب $label',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.search_rounded, size: 19, color: widget.accent),
          ],
        ),
      ),
    );
  }
}

class _SearchableAreaSheet extends StatefulWidget {
  const _SearchableAreaSheet({
    required this.title,
    required this.items,
    required this.accent,
  });

  final String title;
  final List<GeographicalArea> items;
  final Color accent;

  @override
  State<_SearchableAreaSheet> createState() => _SearchableAreaSheetState();
}

class _SearchableAreaSheetState extends State<_SearchableAreaSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items =
        widget.items
            .where((item) => item.name.contains(_query.trim()))
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Column(
            children: [
              Text(
                'انتخاب ${widget.title}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: widget.accent),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: widget.accent),
                  hintText: 'جست‌وجو',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.accent),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    items.isEmpty
                        ? const Center(child: Text('موردی پیدا نشد.'))
                        : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              title: Text(item.name),
                              onTap: () => Navigator.of(context).pop(item),
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
