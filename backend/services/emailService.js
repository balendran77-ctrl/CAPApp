const nodemailer = require('nodemailer');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

let transporter;

const getEmailConfig = () => {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.EMAIL_FROM || user;

  return {
    host,
    port,
    secure,
    user,
    pass,
    from,
  };
};

const isEmailConfigured = () => {
  const { host, port, user, pass, from } = getEmailConfig();
  return Boolean(host && port && user && pass && from);
};

const getTransporter = () => {
  if (transporter) {
    return transporter;
  }

  const { host, port, secure, user, pass } = getEmailConfig();

  transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {
      user,
      pass,
    },
  });

  return transporter;
};

const extractEmails = (value) => {
  if (!value || typeof value !== 'string') {
    return [];
  }

  return [...new Set(
    value
      .split(/[;,\s]+/)
      .map((part) => part.trim())
      .filter((part) => EMAIL_REGEX.test(part.toLowerCase()))
      .map((part) => part.toLowerCase())
  )];
};

const formatDate = (dateValue) => {
  if (!dateValue) {
    return 'Not specified';
  }

  const date = new Date(dateValue);
  if (Number.isNaN(date.getTime())) {
    return 'Not specified';
  }

  return date.toISOString().slice(0, 10);
};

const sendCapAssignmentEmail = async ({ to, capId, title, dueDate, description }) => {
  if (!to || to.length === 0) {
    return { sent: false, reason: 'No recipient email found in assignee field' };
  }

  if (!isEmailConfigured()) {
    return { sent: false, reason: 'SMTP configuration is missing' };
  }

  const { from } = getEmailConfig();
  const transporterInstance = getTransporter();

  const subject = `CAP Assigned: ${title || capId || 'New CAP'}`;
  const dueDateText = formatDate(dueDate);

  const text = [
    'You have been assigned a Critical Action Point (CAP).',
    '',
    `CAP ID: ${capId || 'N/A'}`,
    `Title: ${title || 'N/A'}`,
    `Due Date: ${dueDateText}`,
    `Description: ${description || 'N/A'}`,
    '',
    'Please review and take action.',
  ].join('\n');

  const html = `
    <p>You have been assigned a Critical Action Point (CAP).</p>
    <p><strong>CAP ID:</strong> ${capId || 'N/A'}</p>
    <p><strong>Title:</strong> ${title || 'N/A'}</p>
    <p><strong>Due Date:</strong> ${dueDateText}</p>
    <p><strong>Description:</strong> ${description || 'N/A'}</p>
    <p>Please review and take action.</p>
  `;

  await transporterInstance.sendMail({
    from,
    to,
    subject,
    text,
    html,
  });

  return { sent: true };
};

module.exports = {
  extractEmails,
  sendCapAssignmentEmail,
};
