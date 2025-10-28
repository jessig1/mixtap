# Bug Fixes for Vinylhound

## Fixed Issues

### 1. ✅ Albums Table Schema Mismatch

**Error**: `ERROR: column "tracks" does not exist (SQLSTATE 42703)`

**Problem**: The database schema created by `schema.sql` didn't match what the application code expected. The code expected:
- `tracks` (JSONB array)
- `genres` (JSONB array)
- `user_id` (BIGINT with foreign key)
- `rating` (INTEGER)

**Solution**: Updated the database schema with:
```sql
ALTER TABLE albums
ADD COLUMN user_id BIGINT,
ADD COLUMN tracks JSONB DEFAULT '[]'::jsonb,
ADD COLUMN genres JSONB DEFAULT '[]'::jsonb,
ADD COLUMN rating INTEGER DEFAULT 3 CHECK (rating BETWEEN 1 AND 5);

ALTER TABLE albums
ADD CONSTRAINT albums_user_id_fkey
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

CREATE INDEX idx_albums_user_id ON albums(user_id);
```

**Status**: ✅ Fixed - Albums can now be created and searched properly

### 2. ✅ Missing user_album_preferences Table

**Error**: `ERROR: relation "user_album_preferences" does not exist (SQLSTATE 42P01)`

**Problem**: The database had a `user_preferences` table (for genre preferences), but was missing the `user_album_preferences` table (for album ratings and favorites). The application code queries `user_album_preferences` to:
- Get aggregate album ratings
- Track favorited albums
- Store user-specific album ratings

**Solution**: Created the missing table with:
```sql
CREATE TABLE user_album_preferences (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    album_id BIGINT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    favorited BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, album_id)
);

-- Performance indexes
CREATE INDEX idx_user_album_prefs_album_id ON user_album_preferences(album_id);
CREATE INDEX idx_user_album_prefs_favorited ON user_album_preferences(user_id, favorited);
CREATE INDEX idx_user_album_prefs_updated ON user_album_preferences(user_id, updated_at DESC);
CREATE INDEX idx_user_album_prefs_rating_stats ON user_album_preferences(album_id, rating, user_id);
```

**Status**: ✅ Fixed - Album searches and artist pages now work with aggregate ratings

---

### 3. ✅ Playlist and Song Endpoints - IMPLEMENTED

**Problem**: The backend monolith was missing playlist and song endpoints completely.

**Solution**: Fully implemented playlist and song functionality by copying and adapting code from the microservices architecture:

**New Files Created**:
- `internal/store/playlists.go` - Playlist database operations
- `internal/store/songs.go` - Song database operations
- `internal/app/playlists/service.go` - Playlist business logic
- `internal/httpapi/playlists.go` - Playlist HTTP handlers
- `internal/httpapi/songs.go` - Song HTTP handlers

**Playlist Endpoints Implemented**:
- ✅ `GET /api/v1/playlists` - List user's playlists
- ✅ `POST /api/v1/playlists` - Create playlist
- ✅ `GET /api/v1/playlists/{id}` - Get playlist details
- ✅ `PUT /api/v1/playlists/{id}` - Update playlist
- ✅ `DELETE /api/v1/playlists/{id}` - Delete playlist
- ✅ `POST /api/v1/playlists/{id}/songs` - Add song to playlist
- ✅ `DELETE /api/v1/playlists/{id}/songs/{songId}` - Remove song from playlist

**Song Endpoints Implemented**:
- ✅ `GET /api/v1/songs?q={query}` - Search songs
- ✅ `GET /api/v1/songs?album_id={id}` - Get songs by album
- ✅ `GET /api/v1/songs/{id}` - Get song by ID

**Database Updates**:
- Added `description` and `user_id` columns to `playlists` table
- Added proper foreign key constraints and indexes

**Status**: ✅ COMPLETE - All playlist and song features now work with the frontend

---

## Available Endpoints

### Authentication
- ✅ `POST /api/v1/auth/signup` - User registration
- ✅ `POST /api/v1/auth/login` - User login

### Albums
- ✅ `GET /api/v1/albums` - List all albums (with filters)
- ✅ `GET /api/v1/albums/{id}` - Get album details
- ✅ `POST /api/v1/me/albums` - Create new album
- ✅ `GET /api/v1/me/albums` - Get user's albums
- ✅ `GET /api/v1/me/albums/preferences` - Get user's album preferences
- ✅ `PUT /api/v1/me/albums/{id}/preference` - Update album preference

### Playlists (NEW)
- ✅ `GET /api/v1/playlists` - List user's playlists
- ✅ `POST /api/v1/playlists` - Create playlist
- ✅ `GET /api/v1/playlists/{id}` - Get playlist details
- ✅ `PUT /api/v1/playlists/{id}` - Update playlist
- ✅ `DELETE /api/v1/playlists/{id}` - Delete playlist
- ✅ `POST /api/v1/playlists/{id}/songs` - Add song to playlist
- ✅ `DELETE /api/v1/playlists/{id}/songs/{songId}` - Remove song from playlist

### Songs (NEW)
- ✅ `GET /api/v1/songs?q={query}` - Search songs
- ✅ `GET /api/v1/songs?artist={name}` - Search by artist
- ✅ `GET /api/v1/songs?album={name}` - Search by album
- ✅ `GET /api/v1/songs?album_id={id}` - Get songs by album ID
- ✅ `GET /api/v1/songs/{id}` - Get song by ID

### User Content
- ✅ `GET /api/v1/users/profile` - Get user profile
- ✅ `PUT /api/v1/users/profile` - Update user profile

### Health
- ✅ `GET /health` - Health check endpoint

---

## Database Schema Status

### Complete Tables
- ✅ `users` - User accounts
- ✅ `sessions` - Authentication sessions
- ✅ `albums` - Album catalog (NOW COMPLETE with tracks/genres/user_id/rating)
- ✅ `user_album_preferences` - Album ratings and favorites (NOW CREATED)
- ✅ `artists` - Artist information
- ✅ `songs` - Song catalog
- ✅ `ratings` - User ratings
- ✅ `reviews` - User reviews
- ✅ `user_content` - User content preferences
- ✅ `user_preferences` - Genre preference settings

### Complete with Full API Support
- ✅ `playlists` - NOW HAS FULL API SUPPORT
- ✅ `playlist_songs` - NOW HAS FULL API SUPPORT

---

## Testing Recommendations

1. **Test Album Creation**: Try creating albums with track lists ✅
2. **Test Album Search**: Search by artist, title, or genre ✅
3. **Test Artist Pages**: Browse albums by artist ✅
4. **Test Playlist Creation**: Create playlists and add songs ✅ NOW WORKING
5. **Test Song Search**: Search for songs across the catalog ✅ NOW WORKING
6. **Test Album Details**: View album details with track listings ✅

---

## Architecture Notes

**Current Setup**:
- Frontend: `http://localhost:5173` (dev) or `http://localhost:3000` (prod)
- Backend: `http://localhost:8080`
- Database: PostgreSQL on port `54320` (external) / `5432` (internal)

**Direct Connection**: Frontend → Backend Monolith → Database
- No API Gateway
- All requests go directly to backend
- Data persists in PostgreSQL

---

## Future Work

1. ~~**Implement Playlist Endpoints**~~ - ✅ COMPLETE
2. ~~**Add Song Endpoints**~~ - ✅ COMPLETE
3. **Add Artist Endpoints** - Add routes for artist CRUD operations
4. **Add Unified Search** - Single endpoint for searching across all content
5. **Add Recommendation Engine** - Based on user preferences
6. **Add Collaborative Playlists** - Allow multiple users to edit playlists
7. **Add Playlist Sharing** - Public playlist URLs

---

*Last Updated: 2025-10-26*
