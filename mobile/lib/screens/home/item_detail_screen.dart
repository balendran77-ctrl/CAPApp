import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../models/item.dart';
import '../../services/api_service.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({required this.itemId, super.key});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Future<Item> _itemFuture;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _assigneeController;
  late TextEditingController _completionDetailsController;
  late TextEditingController _correctiveActionController;
  late TextEditingController _remarksController;
  late TextEditingController _teamMembersController;
  late TextEditingController _capexRevexAmountController;
  List<String> _attachments = [];
  bool _isUploading = false;
  Item? _currentItem;
  String? _selectedStatus;
  DateTime? _selectedDueDate;
  DateTime? _selectedExpectedClosureDate;
  String _selectedCapexRevexType = 'NONE';
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _assigneeController = TextEditingController();
    _completionDetailsController = TextEditingController();
    _correctiveActionController = TextEditingController();
    _remarksController = TextEditingController();
    _teamMembersController = TextEditingController();
    _capexRevexAmountController = TextEditingController();
    _itemFuture = _loadItem();
  }

  Future<Item> _loadItem() async {
    try {
      final itemData = await ApiService.getItem(widget.itemId);
      final item = Item.fromJson(itemData);
      _currentItem = item;
      _attachments = item.attachments ?? [];
      _titleController.text = item.title;
      _descriptionController.text = item.description ?? '';
      _assigneeController.text = item.assignee ?? '';
      _completionDetailsController.text = item.completionDetails ?? '';
      _correctiveActionController.text = item.correctiveAction ?? '';
      _remarksController.text = item.remarks ?? '';
      _teamMembersController.text = (item.teamMembers?.join(', ')) ?? '';
      _selectedStatus = item.status;
      _selectedDueDate = item.dueDate;
      _selectedExpectedClosureDate = item.expectedClosureDate;
      _selectedCapexRevexType = item.capexRevexType;
      _capexRevexAmountController.text = item.capexRevexAmount > 0 ? item.capexRevexAmount.toString() : '';
      return item;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await _uploadFileBytes(bytes, picked.name);
      } else {
        final file = File(picked.path);
        await _uploadFile(file);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Image pick/upload failed: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (kIsWeb) {
        final bytes = picked.bytes;
        if (bytes == null) return;
        await _uploadFileBytes(bytes, picked.name);
      } else {
        final filePath = picked.path;
        if (filePath == null) return;
        final file = File(filePath);
        await _uploadFile(file);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Document pick/upload failed: $e');
    }
  }

  Future<void> _uploadFile(File file) async {
    await _uploadWithRef(
      path.basename(file.path),
      (ref) async {
        await ref.putFile(file);
      },
    );
  }

  Future<void> _uploadFileBytes(Uint8List bytes, String originalName) async {
    await _uploadWithRef(
      originalName,
      (ref) async {
        await ref.putData(bytes);
      },
    );
  }

  Future<void> _uploadWithRef(
    String originalName,
    Future<void> Function(Reference ref) upload,
  ) async {
    if (_currentItem == null) {
      setState(() => _errorMessage = 'Item not loaded yet');
      return;
    }
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      var uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        await FirebaseAuth.instance.signInAnonymously();
        uid = FirebaseAuth.instance.currentUser?.uid;
      }
      if (uid == null) {
        throw Exception('Not authenticated for uploads');
      }
      final safeName = path.basename(originalName);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final storagePath = 'caps/$uid/$fileName';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await upload(ref);
      final url = await ref.getDownloadURL();
      setState(() {
        _attachments.add(url);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() => _selectedDueDate = picked);
    }
  }

  void _selectExpectedClosureDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpectedClosureDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedExpectedClosureDate) {
      setState(() => _selectedExpectedClosureDate = picked);
    }
  }

  void _saveChanges() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Validate required fields
      if (_titleController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Title is required');
        setState(() => _isSaving = false);
        return;
      }

      final teamMembers = _teamMembersController.text
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();

      // Safely parse the amount
      double parsedAmount = 0.0;
      if (_capexRevexAmountController.text.isNotEmpty) {
        try {
          parsedAmount = double.parse(_capexRevexAmountController.text);
        } catch (e) {
          setState(() => _errorMessage = 'Invalid amount: Please enter a valid number');
          setState(() => _isSaving = false);
          return;
        }
      }

      final updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text,
        'assignee': _assigneeController.text,
        'dueDate': _selectedDueDate?.toIso8601String(),
        'status': _selectedStatus,
        'completionDetails': _selectedStatus == 'completed' ? _completionDetailsController.text : null,
        'correctiveAction': _correctiveActionController.text,
        'remarks': _remarksController.text,
        'expectedClosureDate': _selectedExpectedClosureDate?.toIso8601String(),
        'teamMembers': teamMembers,
        'capexRevexType': _selectedCapexRevexType,
        'capexRevexAmount': parsedAmount,
        'attachments': _attachments,
      };

      await ApiService.updateItem(widget.itemId, updateData);

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Critical Action Point updated successfully')),
        );
      }
      setState(() => _itemFuture = _loadItem());
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) {
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }
      print('Update Error: $errorMsg');
      setState(() => _errorMessage = errorMsg);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _submitForApproval() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Validate required fields
      if (_titleController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Title is required');
        setState(() => _isSaving = false);
        return;
      }

      final teamMembers = _teamMembersController.text
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();

      // Safely parse the amount
      double parsedAmount = 0.0;
      if (_capexRevexAmountController.text.isNotEmpty) {
        try {
          parsedAmount = double.parse(_capexRevexAmountController.text);
        } catch (e) {
          setState(() => _errorMessage = 'Invalid amount: Please enter a valid number');
          setState(() => _isSaving = false);
          return;
        }
      }

      final submitData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text,
        'assignee': _assigneeController.text,
        'dueDate': _selectedDueDate?.toIso8601String(),
        'correctiveAction': _correctiveActionController.text,
        'remarks': _remarksController.text,
        'expectedClosureDate': _selectedExpectedClosureDate?.toIso8601String(),
        'teamMembers': teamMembers,
        'capexRevexType': _selectedCapexRevexType,
        'capexRevexAmount': parsedAmount,
        'attachments': _attachments,
        'submitForApproval': true,
      };

      await ApiService.updateItem(widget.itemId, submitData);

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Critical Action Point submitted for Management approval')),
        );
      }
      setState(() => _itemFuture = _loadItem());
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) {
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }
      print('Approval Submission Error: $errorMsg');
      setState(() => _errorMessage = errorMsg);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Critical Action Point Details'),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: FutureBuilder<Item>(
        future: _itemFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _itemFuture = _loadItem()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final item = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusTextColor(item.status),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isEditing)
                  _buildEditMode(item)
                else
                  _buildViewMode(item),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewMode(Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Assigned To:', item.assignee ?? 'Unassigned'),
        _buildInfoRow('Due Date:', _formatDate(item.dueDate)),
        if (item.isOverdue)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '⚠ OVERDUE',
                style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (item.description?.isNotEmpty == true)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(item.description!),
              const SizedBox(height: 16),
            ],
          ),
        if (item.status == 'completed' && item.completionDetails?.isNotEmpty == true)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Completion Details', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(item.completionDetails!),
              const SizedBox(height: 16),
            ],
          ),
        if (item.completedAt != null)
          Text(
            'Completed on: ${_formatDate(item.completedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        const SizedBox(height: 24),
        // Display CAP Management Fields
        if (item.correctiveAction?.isNotEmpty == true)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Corrective Action', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(item.correctiveAction!),
              const SizedBox(height: 16),
            ],
          ),
        if (item.remarks?.isNotEmpty == true)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remarks', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(item.remarks!),
              const SizedBox(height: 16),
            ],
          ),
        if (item.expectedClosureDate != null)
          _buildInfoRow('Expected Closure Date:', _formatDate(item.expectedClosureDate)),
        if (item.teamMembers != null && item.teamMembers!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Team Members', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(item.teamMembers!.join(', ')),
              const SizedBox(height: 16),
            ],
          ),
        if (item.capexRevexType != 'NONE')
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Type:', item.capexRevexType),
                if (item.capexRevexAmount > 0)
                  _buildInfoRow('Amount:', '${item.capexRevexAmount.toStringAsFixed(2)} USD'),
              ],
            ),
          ),
        // Approval Status Badge
        if (item.approvalStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: item.approvalStatus == 'approved' ? Colors.green[100] : 
                       item.approvalStatus == 'rejected' ? Colors.red[100] : Colors.yellow[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: item.approvalStatus == 'approved' ? Colors.green : 
                         item.approvalStatus == 'rejected' ? Colors.red : Colors.orange,
                ),
              ),
              child: Text(
                'Approval Status: ${item.approvalStatus.toUpperCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.approvalStatus == 'approved' ? Colors.green[900] : 
                         item.approvalStatus == 'rejected' ? Colors.red[900] : Colors.orange[900],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditMode(Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Title', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Description', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Assign To', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _assigneeController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 16),
        Text('Due Date', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDueDate,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_formatDate(_selectedDueDate))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Status', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: _selectedStatus,
          items: ['pending', 'in-progress', 'completed']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (value) => setState(() => _selectedStatus = value),
        ),
        const SizedBox(height: 16),
        if (_selectedStatus == 'completed')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Completion Details', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _completionDetailsController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe what was completed and any relevant details...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        const SizedBox(height: 24),
        // New CAP Management Fields
        Text('Corrective Action', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _correctiveActionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe the corrective action to be taken...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        // Attachments (photos/documents)
        if (_attachments.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Attachments', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = _attachments[index];
                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.insert_drive_file)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _attachments.removeAt(index)),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.close, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickDocument,
              icon: const Icon(Icons.attach_file),
              label: const Text('Document'),
            ),
            if (_isUploading) ...[
              const SizedBox(width: 12),
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ]
          ],
        ),
        const SizedBox(height: 16),
        Text('Remarks', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _remarksController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Additional remarks or notes...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Expected Closure Date', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectExpectedClosureDate,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_formatDate(_selectedExpectedClosureDate))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Team Members', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _teamMembersController,
          decoration: InputDecoration(
            hintText: 'Names or emails (comma-separated)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.people),
          ),
        ),
        const SizedBox(height: 16),
        Text('CAPEX / REVEX', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedCapexRevexType,
              items: ['CAPEX', 'REVEX', 'NONE']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCapexRevexType = value ?? 'NONE'),
            ),
            const SizedBox(height: 12),
            if (_selectedCapexRevexType != 'NONE')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _capexRevexAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Enter amount in currency',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null && _errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    ' Update Error',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _submitForApproval,
            icon: const Icon(Icons.send),
            label: const Text('Submit for Management Approval'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[100]!;
      case 'in-progress':
        return Colors.blue[100]!;
      case 'completed':
        return Colors.green[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[900]!;
      case 'in-progress':
        return Colors.blue[900]!;
      case 'completed':
        return Colors.green[900]!;
      default:
        return Colors.grey[900]!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeController.dispose();
    _completionDetailsController.dispose();
    _correctiveActionController.dispose();
    _remarksController.dispose();
    _teamMembersController.dispose();
    _capexRevexAmountController.dispose();
    super.dispose();
  }
}
