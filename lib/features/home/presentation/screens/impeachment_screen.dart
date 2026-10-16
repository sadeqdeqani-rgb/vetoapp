import 'package:flutter/material.dart';

import '../../../impeachment/domain/impeachment_office.dart';
import '../../../impeachment/presentation/impeachment_office_hub.dart';
import '../../../impeachment/presentation/impeachment_process_list_screen.dart';
import '../../../impeachment/presentation/impeachment_request_screen.dart';

enum _ImpeachmentSection {
  request('request', 'درخواست استیضاح'),
  supporting('supporting', 'حمایت از استیضاح'),
  scheduled('scheduled', 'مشاهدهٔ زمان‌بندی استیضاح'),
  eligible('eligible', 'شرکت در رأی اعتماد'),
  live('live', 'نتایج زندهٔ رأی اعتماد'),
  finalized('finalized', 'نتایج نهایی رأی اعتماد');

  const _ImpeachmentSection(this.routeCode, this.label);
  final String routeCode;
  final String label;
}

class ImpeachmentScreen extends StatefulWidget {
  const ImpeachmentScreen({super.key, this.interactivePreview = false});

  final bool interactivePreview;

  @override
  State<ImpeachmentScreen> createState() => _ImpeachmentScreenState();
}

class _ImpeachmentScreenState extends State<ImpeachmentScreen> {
  ImpeachmentOffice? _office;
  _ImpeachmentSection? _section;

  @override
  Widget build(BuildContext context) {
    if (widget.interactivePreview) return const ImpeachmentOfficeHub();

    final office = _office;
    final section = _section;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              children: [
                DropdownButtonFormField<ImpeachmentOffice>(
                  initialValue: office,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'سطح استیضاح',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  hint: const Text('یک سطح جغرافیایی انتخاب کنید'),
                  items:
                      ImpeachmentOffice.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() {
                        _office = value;
                        _section = null;
                      }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_ImpeachmentSection>(
                  initialValue: section,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'بخش استیضاح',
                    prefixIcon: Icon(Icons.view_list_outlined),
                  ),
                  hint: const Text('ابتدا سطح استیضاح را انتخاب کنید'),
                  items:
                      _ImpeachmentSection.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      office == null
                          ? null
                          : (value) => setState(() => _section = value),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                office == null || section == null
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'برای مشاهدهٔ اطلاعات، سطح استیضاح و سپس بخش مورد نظر را انتخاب کنید.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : section == _ImpeachmentSection.request
                    ? ImpeachmentRequestScreen(
                      key: ValueKey('${office.code}-${section.name}'),
                      office: office,
                    )
                    : ImpeachmentProcessListScreen(
                      key: ValueKey('${office.code}-${section.name}'),
                      office: office,
                      kind: section.routeCode,
                    ),
          ),
        ],
      ),
    );
  }
}
