import 'package:flutter/material.dart';
import 'package:project_uas/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class Homescreen extends StatefulWidget {
  final String? userEmail;
  final String? userName;

  const Homescreen({super.key, this.userEmail, this.userName});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> todolist = [];
  int updateIndex = -1;
  late AnimationController _drawerController;
  late Animation<Offset> _drawerAnimation;
  bool _isDrawerOpen = false;
  String selectedCategory = 'all';
  final List<Map<String, dynamic>> categories = [
    {'label': 'Semua', 'value': 'all', 'icon': Icons.list},
    {'label': 'Personal', 'value': 'personal', 'icon': Icons.person},
    {'label': 'Shopping', 'value': 'shopping', 'icon': Icons.shopping_cart},
    {'label': 'Work', 'value': 'work', 'icon': Icons.work},
    {'label': 'Study', 'value': 'study', 'icon': Icons.school},
  ];

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _drawerAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerController,
      curve: Curves.easeInOut,
    ));
    _fetchTasks();
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _fetchTasks() async {
    debugPrint('[_fetchTasks] Attempting to fetch tasks. Current User ID: $currentUserId');
    if (currentUserId == null) {
      debugPrint('[_fetchTasks] Current User ID is null. Cannot fetch tasks.');
      return;
    }

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('tasks')
          .orderBy('dateTime', descending: false)
          .get();

      setState(() {
        todolist = snapshot.docs.map((doc) => {
              'id': doc.id,
              'task': doc['task'],
              'dateTime': (doc['dateTime'] as Timestamp).toDate(),
              'description': doc['description'],
              'category': doc['category'],
              'done': doc['done'],
            }).toList();
        debugPrint('[_fetchTasks] Tasks fetched successfully. Number of tasks: ${todolist.length}');
      });
    } catch (e) {
      debugPrint('[_fetchTasks] Error fetching tasks: $e');
    }
  }

  Future<void> addTask(String task, DateTime dateTime, String description, String category) async {
    debugPrint('[addTask] Attempting to add task: $task. Current User ID: $currentUserId');
    if (currentUserId == null) {
      debugPrint('[addTask] Current User ID is null. Cannot add task.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('tasks')
          .add({
        'task': task,
        'dateTime': Timestamp.fromDate(dateTime),
        'description': description,
        'category': category,
        'done': false,
      });
      debugPrint('[addTask] Task added to Firestore. Calling _fetchTasks...');
      await _fetchTasks(); // Refresh list after adding
    } catch (e) {
      debugPrint('[addTask] Error adding task: $e');
    }
  }

  Future<void> updateTask(String taskId, String task, DateTime dateTime, String description, String category, bool done) async {
    debugPrint('[updateTask] Attempting to update task ID: $taskId. Current User ID: $currentUserId');
    if (currentUserId == null) {
      debugPrint('[updateTask] Current User ID is null. Cannot update task.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'task': task,
        'dateTime': Timestamp.fromDate(dateTime),
        'description': description,
        'category': category,
        'done': done,
      });
      debugPrint('[updateTask] Task updated in Firestore. Calling _fetchTasks...');
      await _fetchTasks(); // Refresh list after updating
    } catch (e) {
      debugPrint('[updateTask] Error updating task: $e');
    }
  }

  void deleteItem(int index) async {
    debugPrint('[deleteItem] Attempting to delete task at index: $index. Current User ID: $currentUserId');
    if (currentUserId == null) {
      debugPrint('[deleteItem] Current User ID is null. Cannot delete task.');
      return;
    }

    final taskId = todolist[index]['id'];
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('tasks')
          .doc(taskId)
          .delete();
      debugPrint('[deleteItem] Task deleted from Firestore. Calling _fetchTasks...');
      await _fetchTasks(); // Refresh list after deleting
    } catch (e) {
      debugPrint('[deleteItem] Error deleting task: $e');
    }
  }

  void editTask(int index) async {
    final taskToEdit = todolist[index];
    final TextEditingController _editController = TextEditingController(text: taskToEdit['task']);
    final TextEditingController _editDescriptionController = TextEditingController(text: taskToEdit['description'] ?? '');
    DateTime selectedDate = taskToEdit['dateTime'];
    TimeOfDay selectedTime = TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);
    String selectedEditCategory = taskToEdit['category'];

    await showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _editController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Task',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _editDescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Task (Opsional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8F5AFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text('${selectedTime.format(context)}'),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedTime = picked;
                                  selectedDate = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8F5AFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedEditCategory,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: categories
                          .where((cat) => cat['value'] != 'all')
                          .map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['value'],
                          child: Row(
                            children: [
                              Icon(cat['icon'], color: Color(0xFF8F5AFF)),
                              const SizedBox(width: 8),
                              Text(cat['label']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedEditCategory = val;
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_editController.text.trim().isNotEmpty) {
                      updateTask(
                        taskToEdit['id'],
                        _editController.text.trim(),
                        DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        ),
                        _editDescriptionController.text.trim(),
                        selectedEditCategory,
                        taskToEdit['done'],
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8F5AFF)),
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8F5AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openDrawer() {
    setState(() {
      _isDrawerOpen = true;
    });
    _drawerController.forward();
  }

  void _closeDrawer() {
    _drawerController.reverse().then((_) {
      setState(() {
        _isDrawerOpen = false;
      });
    });
  }

  void addTaskPopup() async {
    final TextEditingController _taskController = TextEditingController();
    final TextEditingController _descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedPopupCategory = 'personal';
    await showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Tambah Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(labelText: 'Nama Task'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Deskripsi Task (Opsional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8F5AFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(selectedTime.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedTime = picked;
                                  selectedDate = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8F5AFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPopupCategory == 'all' ? 'personal' : selectedPopupCategory,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: categories
                          .where((cat) => cat['value'] != 'all')
                          .map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['value'],
                          child: Row(
                            children: [
                              Icon(cat['icon'], color: Color(0xFF8F5AFF)),
                              const SizedBox(width: 8),
                              Text(cat['label']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedPopupCategory = val;
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_taskController.text.trim().isNotEmpty) {
                      await addTask(
                        _taskController.text.trim(),
                        DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        ),
                        _descriptionController.text.trim(),
                        selectedPopupCategory,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8F5AFF)),
                  child: const Text('Tambah'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String getCategoryLabel(String value) {
    final cat = categories.firstWhere((c) => c['value'] == value, orElse: () => {});
    return cat.containsKey('label') ? cat['label'] : value;
  }

  // Helper untuk cek overdue
  bool isOverdue(Map<String, dynamic> task) {
    final now = DateTime.now();
    return !task['done'] && (task['dateTime'].isBefore(now));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          body: SafeArea(
            child: Column(
              children: [
                // Tombol menu di kiri atas
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF8F5AFF), size: 32),
                    onPressed: _openDrawer,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 90,
                  child: (() {
                    List<Map<String, dynamic>> filteredTasks = selectedCategory == 'all'
                        ? todolist
                        : todolist.where((task) => task['category'] == selectedCategory).toList();
                    if (filteredTasks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'lib/assets/animasi_todolist.json',
                              width: 250,
                              height: 250,
                              fit: BoxFit.fill,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada tugas',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        final dateTime = task['dateTime'] as DateTime;
                        final categoryLabel = getCategoryLabel(task['category']);
                        final categoryIcon = categories.firstWhere((c) => c['value'] == task['category'], orElse: () => {})['icon'];
                        final bool isDone = task['done'];
                        final bool overdue = isOverdue(task);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Opacity(
                            opacity: isDone ? 0.5 : 1.0,
                            child: Stack(
                              children: [
                                Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: overdue
                                          ? Colors.red[100]
                                          : Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF8F5AFF).withOpacity(0.12),
                                        child: Icon(categoryIcon ?? Icons.label, color: const Color(0xFF8F5AFF)),
                                      ),
                                      title: Text(
                                        task['task'],
                                        style: TextStyle(
                                          color: Color(0xFF222222),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      subtitle: (task['description'] != null && task['description'].isNotEmpty)
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  task['description'],
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.calendar_today, size: 15, color: Colors.grey[500]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (overdue)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                                                    child: Text(
                                                      'Terlambat!',
                                                      style: TextStyle(
                                                        color: Colors.red[700],
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 6),
                                                Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Chip(
                                                    label: Text(
                                                      categoryLabel,
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF8F5AFF), fontWeight: FontWeight.bold),
                                                    ),
                                                    backgroundColor: const Color(0xFF8F5AFF).withOpacity(0.08),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.calendar_today, size: 15, color: Colors.grey[500]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (overdue)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                                                    child: Text(
                                                      'Terlambat!',
                                                      style: TextStyle(
                                                        color: Colors.red[700],
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 6),
                                                Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Chip(
                                                    label: Text(
                                                      categoryLabel,
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF8F5AFF), fontWeight: FontWeight.bold),
                                                    ),
                                                    backgroundColor: const Color(0xFF8F5AFF).withOpacity(0.08),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: isDone,
                                            onChanged: (val) {
                                              updateTask(
                                                task['id'],
                                                task['task'],
                                                task['dateTime'],
                                                task['description'],
                                                task['category'],
                                                val ?? false,
                                              );
                                            },
                                            activeColor: const Color(0xFF8F5AFF),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Color(0xFF8F5AFF)),
                                            onPressed: () => editTask(index),
                                          ),
                                          IconButton(
                                            onPressed: () => deleteItem(index),
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  })(),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: addTaskPopup,
            backgroundColor: const Color(0xFF8F5AFF),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
        // Sidebar (Drawer) dengan animasi
        if (_isDrawerOpen)
          GestureDetector(
            onTap: _closeDrawer,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        AnimatedBuilder(
          animation: _drawerController,
          builder: (context, child) {
            return FractionalTranslation(
              translation: _drawerAnimation.value,
              child: child,
            );
          },
          child: _isDrawerOpen
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(2, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profil sederhana di atas sidebar
                            Padding(
                              padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 8),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Color(0xFF8F5AFF),
                                    child: Icon(Icons.person, color: Colors.white, size: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.userName ?? 'User Name',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8F5AFF),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.userEmail ?? 'user.email@example.com',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                              child: Text(
                                'Kategori',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8F5AFF),
                                ),
                              ),
                            ),
                            ...categories.map((cat) => ListTile(
                                  leading: Icon(cat['icon'], color: selectedCategory == cat['value'] ? Color(0xFF8F5AFF) : Colors.grey),
                                  title: Text(cat['label'], style: TextStyle(fontWeight: FontWeight.w500, color: selectedCategory == cat['value'] ? Color(0xFF8F5AFF) : Colors.black)),
                                  selected: selectedCategory == cat['value'],
                                  onTap: () {
                                    setState(() {
                                      selectedCategory = cat['value'];
                                    });
                                    _closeDrawer();
                                  },
                                )),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.logout, color: Colors.white),
                                  label: const Text('Logout', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8F5AFF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  onPressed: () {
                                    _closeDrawer();
                                    _handleLogout();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
} 