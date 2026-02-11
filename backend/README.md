# CAP App - Backend

Node.js/Express REST API with MongoDB Atlas integration.

## Features
- User authentication (JWT)
- CRUD operations for Critical Action Points (CAPs)
- Unique CAP ID generation for tracking
- User profiles with image support
- MongoDB Atlas integration
- CORS enabled for mobile/web clients

## Prerequisites
- Node.js 16+ and npm
- MongoDB Atlas account (free tier available at https://www.mongodb.com/cloud/atlas)

## Setup

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure MongoDB Atlas
1. Go to https://www.mongodb.com/cloud/atlas
2. Create a free cluster (M0)
3. Create a database user and get your connection string
4. Copy `.env.example` to `.env` and update:
   ```
   MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/capapp
   JWT_SECRET=your_secret_key
   ```

### 3. Run the Server
```bash
npm run dev
```
Server runs on `http://localhost:5000`

## API Endpoints

### Users
- `POST /api/users/register` - Register new user
- `POST /api/users/login` - Login user
- `GET /api/users/profile` - Get user profile (requires auth)
- `PUT /api/users/profile` - Update profile (requires auth)

### Critical Action Points (CAPs) - all require JWT token in Authorization header
- `POST /api/items` - Create CAP
- `GET /api/items` - Get all user CAPs
- `GET /api/items/:id` - Get CAP by ID
- `PUT /api/items/:id` - Update CAP
- `DELETE /api/items/:id` - Archive CAP

Each CAP includes a unique `capId` for easy tracking and searching.

## Authentication
Include JWT token in headers:
```
Authorization: Bearer <token>
```

## Environment Variables
See `.env.example` for required variables.
