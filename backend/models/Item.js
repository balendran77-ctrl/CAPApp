const mongoose = require('mongoose');

const itemSchema = new mongoose.Schema({
  capId: { type: String, unique: true, trim: true, sparse: true }, // Unique CAP identifier (auto-generated on create)
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true },
  description: { type: String, trim: true },
  assignee: { type: String, trim: true }, // Name or email of assigned person
  dueDate: { type: Date }, // Critical Action Point deadline
  status: { type: String, enum: ['pending', 'in-progress', 'completed', 'approved'], default: 'pending' },
  completionDetails: { type: String, trim: true }, // Details uploaded when marking complete
  completionUploadUrl: { type: String }, // URL to uploaded file/attachment
  attachments: [String], // Array of attachment URLs (images/docs) stored in cloud
  completedAt: { type: Date }, // When was it marked complete
  tags: [String],
  // New fields for detailed CAP management
  correctiveAction: { type: String, trim: true }, // Action to be taken
  remarks: { type: String, trim: true }, // Additional remarks
  expectedClosureDate: { type: Date }, // Expected closure date
  teamMembers: [String], // Array of team member names/emails
  capexRevexType: { type: String, enum: ['CAPEX', 'REVEX', 'NONE'], default: 'NONE' }, // Type of expenditure
  capexRevexAmount: { type: Number, default: 0 }, // Amount in currency
  approvalStatus: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' }, // Management approval status
  approvalNotes: { type: String, trim: true }, // Notes from management
  submittedForApprovalAt: { type: Date }, // When submitted for approval
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

// Auto-update timestamp on save
itemSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('Item', itemSchema);
