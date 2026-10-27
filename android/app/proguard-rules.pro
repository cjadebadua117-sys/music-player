# R8 keep rules for Kotlin types that plugins resolve through JNI.
#
# shared_preferences_android 2.5.0 talks to Dart through Pigeon's JNI bindings,
# which look classes and method descriptors up by name. R8 renames
# kotlin.coroutines.Continuation (to something like `r4.c`) while Flutter's
# plugin classes keep their names, so the looked-up descriptor no longer exists
# and release builds crash with:
#
#   NoSuchMethodError: no non-static method
#   "Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;
#    .getAll(...Lkotlin/coroutines/Continuation;)Ljava/lang/Object;"
#
# Same rules as the upstream fix in flutter/packages#13311
# (tracked in flutter/flutter#194649 and flutter/flutter#193880).
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
