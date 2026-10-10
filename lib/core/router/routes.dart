/// Route paths. Build parameterised paths with the helpers.
abstract final class Routes {
  static const onboarding = '/welcome';
  static const library = '/library';
  static const stage = '/stage';
  static const takes = '/takes';
  static const me = '/me';

  static const rehearse = '/rehearse/:songId';
  static const studio = '/studio/:songId';
  static const review = '/review/:takeId';
  static const post = '/post/:postId';
  static const profile = '/profile/:userId';
  static const signIn = '/sign-in';
  static const editProfile = '/me/edit';

  static String rehearseFor(String songId) => '/rehearse/$songId';
  static String studioFor(String songId) => '/studio/$songId';
  static String reviewFor(String takeId) => '/review/$takeId';
  static String postFor(String postId) => '/post/$postId';
  static String profileFor(String userId) => '/profile/$userId';
}
