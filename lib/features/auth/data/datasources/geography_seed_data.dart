import '../../domain/entities/geographical_area.dart';

abstract final class GeographySeedData {
  static const countries = <GeographicalArea>[
    GeographicalArea(id: 1, name: 'ایران', type: 'country'),
  ];

  static const provinces = <GeographicalArea>[
    GeographicalArea(id: 11, parentId: 1, name: 'فارس', type: 'province'),
    GeographicalArea(id: 12, parentId: 1, name: 'اصفهان', type: 'province'),
    GeographicalArea(id: 13, parentId: 1, name: 'یزد', type: 'province'),
  ];

  static const counties = <GeographicalArea>[
    GeographicalArea(
      id: 111,
      parentId: 11,
      name: 'نورآباد ممسنی',
      type: 'county',
    ),
    GeographicalArea(id: 121, parentId: 12, name: 'شهرضا', type: 'county'),
    GeographicalArea(id: 131, parentId: 13, name: 'یزد', type: 'county'),
  ];

  static const localities = <GeographicalArea>[
    GeographicalArea(
      id: 1111,
      parentId: 111,
      name: 'دهگپ محمودی',
      type: 'locality',
    ),
    GeographicalArea(id: 1211, parentId: 121, name: 'دولقری', type: 'locality'),
    GeographicalArea(
      id: 1311,
      parentId: 131,
      name: 'نعیم آباد',
      type: 'locality',
    ),
  ];

  static List<GeographicalArea> children({int? parentId}) {
    if (parentId == null) return countries;
    return <GeographicalArea>[
      ...provinces,
      ...counties,
      ...localities,
    ].where((item) => item.parentId == parentId).toList(growable: false);
  }
}
