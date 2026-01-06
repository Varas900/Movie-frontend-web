import 'api_permission_entry.dart';

/// Client-side permission map (UX).
///
/// This is a 1:1 translation of the mobile app's `API_PERMISSIONS` list.
///
/// Policy: loose. If an endpoint is not found here, the client will still call
/// the API and let the backend enforce authorization.
///
/// Notes:
/// - `isPublic=true` for GUEST endpoints.
/// - `permission=null` for public endpoints.
/// - Only non-GET requests are pre-blocked by the permission guard.
const List<ApiPermissionEntry> apiPermissions = <ApiPermissionEntry>[
  // Account
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/mfa/totp/start', permission: 'account.mfa_setup', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/mfa/totp/confirm', permission: 'account.mfa_setup', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/mfa/totp/disable', permission: 'account.mfa_setup', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/change/email/start', permission: 'account.change_password', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/change/email/verify', permission: 'account.change_password', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/change/mfa/verify', permission: 'account.change_password', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/change/commit', permission: 'account.change_password', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/forgot/email/start', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/forgot/email/verify', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/forgot/mfa/verify', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/account/password/forgot/commit', permission: null, isPublic: true),

  // ArchiveUpload
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/upload/archive/file', permission: 'upload.archive', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/upload/archive/link', permission: 'upload.archive', isPublic: false),

  // Comment
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Comment/GetCommentByID/{id}', permission: 'comment.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Comment/GetCommentsByUserID/{userID}', permission: 'comment.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Comment/GetCommentsByMovieID/{movieID}', permission: 'comment.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/Comment/CreateComment', permission: 'comment.create', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/Comment/UpdateComment', permission: 'comment.update_own', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/Comment/DeleteComment/{id}', permission: 'comment.delete_own', isPublic: false),

  // Episode
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Episode/GetEpisodeById/{id}', permission: 'episode.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Episode/GetAllEpisodes/getAll', permission: 'episode.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Episode/GetEpisodesByMovieId/getbyMovie/{movieId}', permission: 'episode.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/Episode/CreateEpisode', permission: 'episode.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/Episode/UpdateEpisode', permission: 'episode.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/Episode/DeleteEpisode/{id}', permission: 'episode.manage', isPublic: false),

  // EpisodeSource
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/EpisodeSource/GetEpisodeSourceById/{id}', permission: 'source.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/EpisodeSource/GetEpisodeSourcesByEpisodeId/{episodeId}', permission: 'source.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/EpisodeSource/CreateEpisodeSource', permission: 'source.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/EpisodeSource/UpdateEpisodeSource', permission: 'source.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/EpisodeSource/DeleteEpisodeSource/{id}', permission: 'source.manage', isPublic: false),

  // EpisodeWatchProgress
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/EpisodeWatchProgress/CreateEpisodeWatchProgress', permission: 'progress.track', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/EpisodeWatchProgress/UpdateEpisodeWatchProgress', permission: 'progress.track', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/EpisodeWatchProgress/DeleteEpisodeWatchProgress/{id}', permission: 'progress.track', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/EpisodeWatchProgress/GetEpisodeWatchProgressByID/{id}', permission: 'progress.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/EpisodeWatchProgress/GetEpisodeWatchProgressByUserID/user/{userId}', permission: 'progress.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/EpisodeWatchProgress/GetEpisodeWatchProgressByEpisodeID/episode/{episodeId}', permission: 'progress.read', isPublic: false),

  // Health
  ApiPermissionEntry(method: 'GET', pathTemplate: '/healthz', permission: null, isPublic: true),

  // ImageSource
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/ImageSource/GetImageSourcesByType/{Type}', permission: 'image.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/ImageSource/CreateImageSource', permission: 'image.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/ImageSource/UpdateImageSource', permission: 'image.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/ImageSource/DeleteImageSource/{id}', permission: 'image.manage', isPublic: false),

  // Invoice
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/invoice/{orderID}', permission: 'invoice.read_own', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/invoice/user/{userID}', permission: 'invoice.read_own', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/invoice/all', permission: 'invoice.read_all', isPublic: false),

  // Login
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/logout', permission: 'auth.logout', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/logout/session/{sessionId}', permission: 'auth.logout', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/logout/all', permission: 'auth.logout', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/auth/refresh', permission: 'auth.refresh', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/userLogin', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/login/mobile', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/login/google-login', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/login/mobile/google', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/login/google/callback', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/login/signin-google', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/login/mfa/verify', permission: null, isPublic: true),

  // Movie
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Movie/GetMovieById/{id}', permission: 'movie.read_details', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Movie/GetAllMovies/gellAll', permission: 'movie.browse', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Movie/GetAllMoviesMainScreen/mainScreen', permission: 'movie.browse', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Movie/GetAllMoviesNewReleaseMainScreen/newReleaseMainScreen', permission: 'movie.browse', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/Movie/GetWatchNowMovieByID/watchNow/{id}', permission: 'movie.watch_stream', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/Movie/CreateMovie', permission: 'movie.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/Movie/UpdateMovie', permission: 'movie.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/Movie/DeleteMovie/{id}', permission: 'movie.manage', isPublic: false),

  // MoviePerson
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MoviePerson/GetMoviesByPerson/{personID}', permission: 'movie_person.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MoviePerson/GetPersonsByMovie/{movieID}', permission: 'movie_person.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/MoviePerson/AddPersonToMovie', permission: 'movie_person.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/MoviePerson/RemovePersonFromMovie/{id}', permission: 'movie_person.manage', isPublic: false),

  // MovieSource
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/movies/{movieId}/vip-source', permission: 'movie.watch_vip', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MovieSource/GetMovieSourceById/{id}', permission: 'source.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/{movieId}', permission: 'source.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/MovieSource/CreateMovieSource', permission: 'source.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/MovieSource/UpdateMovieSource', permission: 'source.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/MovieSource/DeleteMovieSource/{id}', permission: 'source.manage', isPublic: false),

  // MovieSubTitle
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/MovieSubTitle/GetAllSubTitlesByMovieId/movie/GetAllSubTitlesBySourceID/{sourceID}', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/MovieSubTitle/GetAllSubTitles/movie/GetAllSubTitles', permission: 'subtitle.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/MovieSubTitle/GetMovieSubTitleByID/movie/GetMovieSubTitleByID/{movieSubTitleID}', permission: 'subtitle.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/MovieSubTitle/GetAllSubTitlesByEpisodeId/episode/GetAllSubTitlesBySourceID/{sourceID}', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/EpisodeSubTitle/GetEpisodeSubTitlesBySourceID/{sourceId}', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/MovieSubTitle/GetEpisodeSubTitleByID/episode/GetEpisodeSubTitleByID/{episodeSubTitleID}', permission: 'subtitle.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/MovieSubTitle/GetAllEpisodeSubTitles/episode/GetAllSubTitles', permission: 'subtitle.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/MovieSubTitle/ReceiveTranscribeCallback/Callback/TranscribeResult', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/MovieSubTitle/UploadMovieSubTitle/UploadMovieSubTitle', permission: 'subtitle.upload', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/MovieSubTitle/TranslateFromSource/Translate/AutoFromSource', permission: 'subtitle.translate', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/MovieSubTitle/CreateMovieSubTitle/movie/createMovieSubTitle', permission: 'subtitle.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/MovieSubTitle/UpdateMovieSubTitle/movie/updateMovieSubTitle', permission: 'subtitle.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/MovieSubTitle/DeleteMovieSubTitle/movie/deleteMovieSubTitle/{movieSubTitleID}', permission: 'subtitle.manage', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/MovieSubTitle/CreateEpisodeSubTitle/episode/createEpisodeSubTitle', permission: 'subtitle.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/MovieSubTitle/UpdateEpisodeSubTitle/episode/updateEpisodeSubTitle', permission: 'subtitle.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/MovieSubTitle/DeleteEpisodeSubTitle/episode/deleteMovieSubTitle/{episodeSubTitleID}', permission: 'subtitle.manage', isPublic: false),

  // MovieTag
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MovieTag/GetMoviesByTag/{tagID}', permission: 'movie_tag.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MovieTag/GetTagsByMovie/{movieID}', permission: 'movie_tag.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/MovieTag/GetMoviesByTagIDs/getMovieByTagID', permission: 'movie_tag.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/MovieTag/AddTagToMovie', permission: 'movie_tag.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/MovieTag/UpdateMovieTag', permission: 'movie_tag.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/MovieTag/DeleteMovieTag/{id}', permission: 'movie_tag.manage', isPublic: false),

  // Order
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/order/{orderID}', permission: 'order.read_own', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/order/user/{userID}', permission: 'order.read_own', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/order/all', permission: 'order.read_all', isPublic: false),

  // Payment
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/payment/vnpay/checkout', permission: 'payment.checkout', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/vnpay/callback', permission: null, isPublic: true),

  // Permission
  ApiPermissionEntry(method: 'POST', pathTemplate: '/permissions/addPermission', permission: 'permission.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/permissions/updatePermission', permission: 'permission.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/permissions/delate', permission: 'permission.manage', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/permissions/BulkCreate', permission: 'permission.manage', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/permissions/getall', permission: 'permission.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/permissions/getbyid', permission: 'permission.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/permissions/getbyUserID/{ID}', permission: 'permission.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/permissions/getbyRoleID/{ID}', permission: 'permission.read', isPublic: false),

  // Person
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Person/GetPersonByID/{ID}', permission: 'person.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Person/GetAllPerson/getall', permission: 'person.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/Person/CreatePerson', permission: 'person.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/Person/UpdatePerson', permission: 'person.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/Person/DeletePerson/{id}', permission: 'person.manage', isPublic: false),

  // Plan
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/plans/{planID}', permission: 'plan.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/plans/all', permission: 'plan.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/plans/create', permission: 'plan.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/plans/update', permission: 'plan.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/plans/delete/{planID}', permission: 'plan.manage', isPublic: false),

  // Price
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/price/{priceID}', permission: 'price.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/price/all', permission: 'price.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/price/Create', permission: 'price.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/price/Update', permission: 'price.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/price/Delete/{priceID}', permission: 'price.manage', isPublic: false),

  // Region
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Region/GetRegionByID/{ID}', permission: 'region.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Region/GetAllRegions/getAll', permission: 'region.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Region/GetMovieByRegionID/getMovieByRegionID/{regionID}', permission: 'region.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Region/GetPersonByRegionID/getPersonByRegionID/{regionID}', permission: 'region.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/Region/CreateRegion', permission: 'region.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/Region/UpdateRegion', permission: 'region.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/Region/DeleteRegion/{id}', permission: 'region.manage', isPublic: false),

  // Register
  ApiPermissionEntry(method: 'POST', pathTemplate: '/register', permission: null, isPublic: true),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/register/verifyRegisterEmail', permission: null, isPublic: true),

  // Role
  ApiPermissionEntry(method: 'GET', pathTemplate: '/roles/getall', permission: 'role.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/roles/addRole', permission: 'role.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/roles/updateRole', permission: 'role.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/roles/deleteRole/{roleID}', permission: 'role.manage', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/roles/getRoleByUserID/{userID}', permission: 'role.read', isPublic: false),

  // RolePermission
  ApiPermissionEntry(method: 'POST', pathTemplate: '/role-permissions/assign-permissions', permission: 'permission.assign', isPublic: false),

  // SavedMovie
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/SavedMovie/CreateSavedMovie', permission: 'saved_movie.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/SavedMovie/UpdateSavedMovie', permission: 'saved_movie.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/SavedMovie/DeleteSavedMovie/{id}', permission: 'saved_movie.manage', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/SavedMovie/GetSavedMovieByID/{id}', permission: 'saved_movie.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/SavedMovie/GetSavedMoviesByUserID/user/{userId}', permission: 'saved_movie.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/SavedMovie/GetSavedMoviesByMovieID/movie/{movieId}', permission: 'saved_movie.read', isPublic: false),

  // Search
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/search/movies/reset-index', permission: 'search.manage', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/search/movies/sync-orphans', permission: 'search.manage', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/search/movies', permission: 'search.movie', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/search/movies/suggest', permission: 'search.suggest', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/search/persons', permission: 'search.person', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/search/movies/all', permission: 'search.advanced', isPublic: false),

  // Subscription
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/subscription/all', permission: 'subscription.read_all', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/payment/subscription/expire-due', permission: 'subscription.manage', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/subscription/{subscriptionID}', permission: 'subscription.read_own', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/payment/subscription/user/{userID}', permission: 'subscription.read_own', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/payment/subscription/cancel-subs', permission: 'subscription.cancel', isPublic: false),

  // Tag
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Tag/GetTagById/{TagID}', permission: 'tag.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/Tag/GetAllTags/getALlTags', permission: 'tag.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/Tag/CreateTag', permission: 'tag.manage', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/Tag/UpdateTag', permission: 'tag.manage', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/Tag/DeleteTag/{id}', permission: 'tag.manage', isPublic: false),

  // User
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/user/deleteUser', permission: 'user.delete', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/user/me', permission: 'user.read_profile', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/user/update/profile', permission: 'user.update_profile', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/user/update/username', permission: 'user.update_profile', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/user/getAllUsers', permission: 'user.read_list', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/user/getUserById', permission: 'user.read_details', isPublic: false),

  // UserRating
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/UserRating/GetUserRatingById/{ID}', permission: 'rating.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/UserRating/GetAllUserRatingsByUserId/{userID}', permission: 'rating.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/api/UserRating/GetAllUserRatingsByMovieId/{movieID}', permission: 'rating.read', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/UserRating/CreateUserRating', permission: 'rating.create', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/api/UserRating/UpdateUserRating', permission: 'rating.update', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/api/UserRating/DeleteUserRating/{id}', permission: 'rating.delete', isPublic: false),

  // UserRole
  ApiPermissionEntry(method: 'POST', pathTemplate: '/user-roles/assign-roles', permission: 'role.assign', isPublic: false),

  // VimeoUpload
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/upload/vimeo/file', permission: 'upload.vimeo', isPublic: false),
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/upload/vimeo/link', permission: 'upload.vimeo', isPublic: false),

  // WatchProgress
  ApiPermissionEntry(method: 'POST', pathTemplate: '/movie/WatchProgress/CreateWatchProgress', permission: 'progress.track', isPublic: false),
  ApiPermissionEntry(method: 'PUT', pathTemplate: '/movie/WatchProgress/UpdateWatchProgress', permission: 'progress.track', isPublic: false),
  ApiPermissionEntry(method: 'DELETE', pathTemplate: '/movie/WatchProgress/DeleteWatchProgress/{id}', permission: 'progress.track', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/WatchProgress/GetWatchProgressByUserId/{userId}', permission: 'progress.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/WatchProgress/GetWatchProgressByID/{ID}', permission: 'progress.read', isPublic: false),
  ApiPermissionEntry(method: 'GET', pathTemplate: '/movie/WatchProgress/GetWatchProgressByMovieId/{movieId}', permission: 'progress.read', isPublic: false),

  // YouTubeUpload
  ApiPermissionEntry(method: 'POST', pathTemplate: '/api/upload/youtube/file', permission: 'upload.youtube', isPublic: false),
];
