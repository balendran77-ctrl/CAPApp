const Item = require('../models/Item');
const { extractEmails, sendCapAssignmentEmail } = require('../services/emailService');

// Create Critical Action Point (CAP)
exports.createItem = async (req, res) => {
  try {
    const { title, description, assignee, dueDate, tags } = req.body;
    
    // Generate unique CAP ID
    const capCount = await Item.countDocuments({ userId: req.userId });
    const capId = `CAP-${req.userId.toString().slice(-6)}-${String(capCount + 1).padStart(4, '0')}`;
    
    const item = new Item({
      capId,
      userId: req.userId,
      title,
      description,
      assignee,
      dueDate,
      status: 'pending',
      tags,
    });

    await item.save();

    const assigneeEmails = extractEmails(assignee);
    if (assigneeEmails.length > 0) {
      sendCapAssignmentEmail({
        to: assigneeEmails,
        capId: item.capId,
        title: item.title,
        dueDate: item.dueDate,
        description: item.description,
      }).catch((err) => {
        console.error('Failed to send CAP assignment email:', err.message);
      });
    }

    res.status(201).json({ message: 'Critical Action Point created', item });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get all Critical Action Points for user
exports.getItems = async (req, res) => {
  try {
    const items = await Item.find({ userId: req.userId, status: { $ne: 'archived' } }).sort({
      createdAt: -1,
    });
    res.json(items);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get item by ID
exports.getItemById = async (req, res) => {
  try {
    const item = await Item.findById(req.params.id);
    if (!item || item.userId.toString() !== req.userId) {
      return res.status(404).json({ error: 'Item not found' });
    }
    res.json(item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Update item (including status changes and completion)
exports.updateItem = async (req, res) => {
  try {
    const { 
      title, description, assignee, dueDate, status, completionDetails, completionUploadUrl, tags,
      correctiveAction, remarks, expectedClosureDate, teamMembers, capexRevexType, capexRevexAmount, 
      approvalNotes, submitForApproval
    } = req.body;
    // attachments: array of file URLs (optional)
    const { attachments } = req.body;
    
    let item = await Item.findById(req.params.id);
    if (!item || item.userId.toString() !== req.userId) {
      return res.status(404).json({ error: 'CAP not found' });
    }

    const previousAssignee = item.assignee || '';

    // Update basic fields (only update if provided)
    if (title !== undefined && title !== null) item.title = title;
    if (description !== undefined && description !== null) item.description = description;
    if (assignee !== undefined && assignee !== null) item.assignee = assignee;
    if (dueDate !== undefined && dueDate !== null) item.dueDate = dueDate;
    if (tags !== undefined && tags !== null) item.tags = tags;

    // Update new CAP management fields (only if provided)
    if (correctiveAction !== undefined && correctiveAction !== null) item.correctiveAction = correctiveAction;
    if (remarks !== undefined && remarks !== null) item.remarks = remarks;
    if (expectedClosureDate !== undefined && expectedClosureDate !== null) item.expectedClosureDate = expectedClosureDate;
    if (teamMembers !== undefined && teamMembers !== null) item.teamMembers = teamMembers;
    if (capexRevexType !== undefined && capexRevexType !== null) item.capexRevexType = capexRevexType;
    if (capexRevexAmount !== undefined && capexRevexAmount !== null) item.capexRevexAmount = parseFloat(capexRevexAmount) || 0;
    if (approvalNotes !== undefined && approvalNotes !== null) item.approvalNotes = approvalNotes;
    if (attachments !== undefined && attachments !== null) item.attachments = attachments;

    // Handle submission for approval
    if (submitForApproval === true) {
      item.approvalStatus = 'pending';
      item.submittedForApprovalAt = Date.now();
      item.status = 'approved'; // Mark as submitted for approval
    }

    // Handle status change
    if (status !== undefined && status !== null && !submitForApproval) {
      item.status = status;
      
      // If marking as completed, record completion timestamp
      if (status === 'completed') {
        item.completedAt = Date.now();
        if (completionDetails) item.completionDetails = completionDetails;
        if (completionUploadUrl) item.completionUploadUrl = completionUploadUrl;
      }
    }

    item.updatedAt = Date.now();
    await item.save();

    if (assignee !== undefined && assignee !== null) {
      const previousEmails = new Set(extractEmails(previousAssignee));
      const currentEmails = extractEmails(item.assignee || '');
      const newlyAssignedEmails = currentEmails.filter((email) => !previousEmails.has(email));

      if (newlyAssignedEmails.length > 0) {
        sendCapAssignmentEmail({
          to: newlyAssignedEmails,
          capId: item.capId,
          title: item.title,
          dueDate: item.dueDate,
          description: item.description,
        }).catch((err) => {
          console.error('Failed to send CAP reassignment email:', err.message);
        });
      }
    }

    res.json({ message: 'Critical Action Point updated', item });
  } catch (error) {
    console.error('Error updating item:', error);
    res.status(500).json({ error: error.message });
  }
};

// Archive Critical Action Point (soft delete)
exports.deleteItem = async (req, res) => {
  try {
    const item = await Item.findById(req.params.id);
    if (!item || item.userId.toString() !== req.userId) {
      return res.status(404).json({ error: 'CAP not found' });
    }

    item.status = 'archived';
    await item.save();

    res.json({ message: 'Critical Action Point archived' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
