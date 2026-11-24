import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const LamaranApp());
}

class LamaranApp extends StatelessWidget {
  const LamaranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lamaran Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B5CE2),
          primary: const Color(0xFF5B5CE2),
        ),
        fontFamily: null,
      ),
      home: const HomePage(),
    );
  }
}

class ApplicationRecord {
  ApplicationRecord({
    required this.id,
    required this.company,
    required this.position,
    required this.status,
    this.imageBase64,
  });

  final String id;
  final String company;
  final String position;
  final String status;
  final String? imageBase64;

  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company,
        'position': position,
        'status': status,
        'imageBase64': imageBase64,
      };

  factory ApplicationRecord.fromJson(Map<String, dynamic> json) {
    return ApplicationRecord(
      id: json['id'] as String,
      company: json['company'] as String,
      position: json['position'] as String,
      status: json['status'] as String,
      imageBase64: json['imageBase64'] as String?,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _storageKey = 'lamaran_records';

  int _selectedIndex = 0;
  List<ApplicationRecord> _records = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _records = decoded
          .map((item) =>
              ApplicationRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_records.map((item) => item.toJson()).toList()),
    );
  }

  void _openForm({ApplicationRecord? record}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: ApplicationFormPage(
            record: record,
            onSave: (saved) {
              setState(() {
                final index =
                    _records.indexWhere((item) => item.id == saved.id);
                if (index >= 0) {
                  _records[index] = saved;
                } else {
                  _records.insert(0, saved);
                }
                _selectedIndex = 1;
              });
              _saveRecords();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRecord(ApplicationRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus lamaran?'),
        content: Text(
          'Lamaran ke ${record.company} akan dihapus dari riwayat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE34D59),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() {
      _records.removeWhere((item) => item.id == record.id);
    });
    await _saveRecords();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ApplicationFormPage(onSave: (record) {
        setState(() {
          _records.insert(0, record);
          _selectedIndex = 1;
        });
        _saveRecords();
      }),
      HistoryPage(
        records: _records,
        onEdit: (record) => _openForm(record: record),
        onDelete: _deleteRecord,
      ),
    ];

    return Scaffold(
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE9EDF5))),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 68,
            elevation: 0,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFEAEAFF),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Tambah',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApplicationFormPage extends StatefulWidget {
  const ApplicationFormPage({
    super.key,
    this.record,
    required this.onSave,
  });

  final ApplicationRecord? record;
  final ValueChanged<ApplicationRecord> onSave;

  @override
  State<ApplicationFormPage> createState() => _ApplicationFormPageState();
}

class _ApplicationFormPageState extends State<ApplicationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  String _status = 'Menunggu';
  String? _imageBase64;

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _companyController.text = widget.record!.company;
      _positionController.text = widget.record!.position;
      _status = widget.record!.status;
      _imageBase64 = widget.record!.imageBase64;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _imageBase64 = base64Encode(bytes);
    });
  }

  Future<void> _showImagePreview() async {
    final imageBase64 = _imageBase64;
    if (imageBase64 == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                child: Image.memory(
                  base64Decode(imageBase64),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF343B4C),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final record = ApplicationRecord(
      id: widget.record?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      company: _companyController.text.trim(),
      position: _positionController.text.trim(),
      status: _status,
      imageBase64: _imageBase64,
    );
    widget.onSave(record);

    if (widget.record != null) {
      Navigator.of(context).pop();
    } else {
      _companyController.clear();
      _positionController.clear();
      setState(() {
        _status = 'Menunggu';
        _imageBase64 = null;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            widget.record != null ? 'Lamaran diperbarui' : 'Lamaran disimpan'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isEditing)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Lamaran' : 'Lamaran Kerja',
                          style: const TextTheme().headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1D2433),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEditing
                              ? 'Perbarui informasi lamaran'
                              : 'Catat dan pantau progresmu',
                          style: const TextStyle(
                            color: Color(0xFF7C8494),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6868E8), Color(0xFF9293F5)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.work_outline_rounded,
                        color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF384A7C).withOpacity(.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Nama Perusahaan'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _companyController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        'Contoh: PT Teknologi Nusantara',
                        Icons.business_outlined,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nama perusahaan wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('Posisi yang Dilamar'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _positionController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        'Contoh: UI/UX Designer',
                        Icons.badge_outlined,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Posisi wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('Status Lamaran'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ['Menunggu', 'Diterima', 'Ditolak'].map((status) {
                        final selected = _status == status;
                        final color = _statusColor(status);
                        return ChoiceChip(
                          label: Text(status),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _status = status),
                          selectedColor: color.withOpacity(.15),
                          side: BorderSide(
                            color: selected ? color : const Color(0xFFE3E7EF),
                          ),
                          labelStyle: TextStyle(
                            color: selected ? color : const Color(0xFF697184),
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: const Color(0xFFF9FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('Gambar Lowongan'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap:
                          _imageBase64 == null ? _pickImage : _showImagePreview,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: _imageBase64 == null ? 128 : 190,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE1E5EE),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _imageBase64 == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 34,
                                    color: Color(0xFF8A93A6),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Unggah gambar (opsional)',
                                    style: TextStyle(
                                      color: Color(0xFF697184),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    base64Decode(_imageBase64!),
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      onPressed: () =>
                                          setState(() => _imageBase64 = null),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: IconButton.filled(
                                      onPressed: _pickImage,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            const Color(0xFF5B5CE2),
                                      ),
                                      tooltip: 'Ganti gambar',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    left: 10,
                                    bottom: 12,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0x99000000),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        child: Text(
                                          'Ketuk untuk melihat',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: Icon(isEditing
                            ? Icons.check_circle_outline
                            : Icons.save_outlined),
                        label: Text(
                          isEditing ? 'Simpan Perubahan' : 'Simpan Lamaran',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5B5CE2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA5ABBA), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF8D94A5), size: 21),
      filled: true,
      fillColor: const Color(0xFFF8F9FD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE1E5EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE1E5EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF5B5CE2), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE34D59)),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF343B4C),
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.records,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ApplicationRecord> records;
  final ValueChanged<ApplicationRecord> onEdit;
  final ValueChanged<ApplicationRecord> onDelete;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _filter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'Semua'
        ? widget.records
        : widget.records.where((item) => item.status == _filter).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat Lamaran',
                  style: TextStyle(
                    color: Color(0xFF1D2433),
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.records.length} lamaran tercatat',
                  style: const TextStyle(color: Color(0xFF7C8494)),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Semua', 'Menunggu', 'Diterima', 'Ditolak']
                        .map((filter) {
                      final selected = _filter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = filter),
                          selectedColor: const Color(0xFF5B5CE2),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF697184),
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE4E7EF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: const BoxDecoration(
                            color: Color(0xFFECECFD),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.folder_off_outlined,
                            size: 40,
                            color: Color(0xFF797AE2),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Belum ada lamaran',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Lamaran yang disimpan akan tampil di sini',
                          style: TextStyle(color: Color(0xFF9299A8)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      return _ApplicationCard(
                        record: record,
                        onEdit: () => widget.onEdit(record),
                        onDelete: () => widget.onDelete(record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final ApplicationRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF384A7C).withOpacity(.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: record.imageBase64 != null
                ? Image.memory(
                    base64Decode(record.imageBase64!),
                    fit: BoxFit.cover,
                  )
                : const Icon(
                    Icons.business_rounded,
                    color: Color(0xFF7778DE),
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF252B3A),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7B8393),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: const Color(0xFF6667CB),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Hapus',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xFFE34D59),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'Diterima':
      return const Color(0xFF25A66A);
    case 'Ditolak':
      return const Color(0xFFE34D59);
    default:
      return const Color(0xFFE89B32);
  }
}
