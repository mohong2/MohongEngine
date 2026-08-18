package org.haxe.extension;

/*
 * SeiunOverlay - Android floating keyboard button.
 *
 * A single draggable button shown above other apps, built on
 * WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY (Android 8.0 / API 26+,
 * the rounded modern Google-style overlay window class; TYPE_PHONE fallback
 * on API 21-25). Tapping the button toggles the system soft keyboard, so
 * players can summon the keyboard anywhere (chat / console input in mods).
 *
 * Requires android.permission.SYSTEM_ALERT_WINDOW (user must grant
 * "Display over other apps" - we take them to the system settings page).
 * The icon is drawn in code, no image assets needed.
 */

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.Toast;

public class SeiunOverlay extends Extension
{
	public static final String LOG_TAG = "SeiunOverlay";

	private static final String PREFS_NAME = "seiun_overlay";
	private static final String KEY_AUTO_SHOW = "auto_show";
	private static final String KEY_ENABLED = "enabled";

	private static WindowManager windowManager;
	private static ImageView button;
	private static WindowManager.LayoutParams overlayParams;
	private static boolean visible = false;
	private static boolean keyboardShowing = false;
	private static boolean autoShow = true;
	private static boolean enabled = true;

	// Drag state
	private static float downRawX = 0;
	private static float downRawY = 0;
	private static float downWindowX = 0;
	private static float downWindowY = 0;
	private static boolean dragging = false;
	private static long downTime = 0;

	// Disposable EditText used to summon the soft keyboard without taking
	// focus away from the game permanently.
	private static EditText keyboardProbe;

	// ------------------------------------------------------------------
	// Public API (called from Haxe through JNI)
	// ------------------------------------------------------------------

	public static boolean isOverlayPermissionGranted()
	{
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
		{
			return Settings.canDrawOverlays(mainContext);
		}
		return true; // Pre-M overlay permission is granted at install time
	}

	/** Open the system "Display over other apps" settings page for this app. */
	public static void requestOverlayPermission()
	{
		if (mainActivity == null)
		{
			Log.e(LOG_TAG, "requestOverlayPermission: mainActivity is null");
			return;
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
		{
			try
			{
				Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
					Uri.parse("package:" + packageName));
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				mainActivity.startActivity(intent);
			}
			catch (Exception e)
			{
				Log.e(LOG_TAG, "requestOverlayPermission: " + e.toString());
				try
				{
					Intent fallback = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
					fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
					mainActivity.startActivity(fallback);
				}
				catch (Exception e2)
				{
					Log.e(LOG_TAG, "requestOverlayPermission fallback: " + e2.toString());
				}
			}
		}
		else
		{
			toast("Floating keyboard is already available on this Android version.");
		}
	}

	public static void show()
	{
		showAt(-1, -1);
	}

	/**
	 * Show the floating button.
	 *
	 * @param x absolute x in px, or -1 to keep the current/default position.
	 * @param y absolute y in px, or -1 to keep the current/default position.
	 */
	public static void showAt(int x, int y)
	{
		if (mainActivity == null)
		{
			Log.e(LOG_TAG, "show: mainActivity is null");
			return;
		}

		final int targetX = x;
		final int targetY = y;

		// All WindowManager / view operations must run on the UI thread -
		// Haxe's frame loop may call us from a non-UI thread.
		mainActivity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				showOnUiThread(targetX, targetY);
			}
		});
	}

	private static void showOnUiThread(int x, int y)
	{
		if (visible)
		{
			if (x >= 0 && y >= 0 && overlayParams != null)
			{
				overlayParams.x = x;
				overlayParams.y = y;
				try
				{
					windowManager.updateViewLayout(button, overlayParams);
				}
				catch (Exception e) {}
			}
			return;
		}

		if (mainContext == null)
		{
			Log.e(LOG_TAG, "show: context not ready");
			return;
		}

		if (!isOverlayPermissionGranted())
		{
			Log.w(LOG_TAG, "show: SYSTEM_ALERT_WINDOW not granted");
			toast("Floating keyboard needs \"Display over other apps\" permission!");
			return;
		}

		try
		{
			windowManager = (WindowManager) mainContext.getSystemService(Context.WINDOW_SERVICE);
			if (windowManager == null)
			{
				Log.e(LOG_TAG, "show: WindowManager is null");
				return;
			}

			if (button == null)
				createButton();
			if (button == null)
				return;

			int size = dp(52);
			int type = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
				? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY // Android 8.0+ modern rounded overlay
				: WindowManager.LayoutParams.TYPE_PHONE;             // fallback for API 21-25

			int flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
				| WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
				| WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS;

			overlayParams = new WindowManager.LayoutParams(
				size,
				size,
				type,
				flags,
				android.graphics.PixelFormat.TRANSLUCENT);
			overlayParams.gravity = Gravity.TOP | Gravity.START;
			overlayParams.x = (x >= 0) ? x : loadSavedX(size);
			overlayParams.y = (y >= 0) ? y : loadSavedY(size);

			windowManager.addView(button, overlayParams);
			visible = true;
			Log.i(LOG_TAG, "Overlay shown at (" + overlayParams.x + ", " + overlayParams.y + ")");
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "show: " + e.toString());
			toast("Toolbar failed to show: " + e.getMessage());
		}
	}

	public static void hide()
	{
		dismissKeyboard();
		if (mainActivity == null)
			return;

		mainActivity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				hideOnUiThread();
			}
		});
	}

	private static void hideOnUiThread()
	{
		if (visible && windowManager != null && button != null)
		{
			try
			{
				windowManager.removeView(button);
			}
			catch (Exception e)
			{
				Log.e(LOG_TAG, "hide: " + e.toString());
			}
		}
		visible = false;
	}

	public static boolean isShowing()
	{
		return visible;
	}

	public static void toggleKeyboard()
	{
		if (mainActivity == null)
			return;
		mainActivity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				if (keyboardShowing)
					dismissKeyboard();
				else
					showKeyboard();
			}
		});
	}

	public static void showKeyboard()
	{
		if (mainActivity == null)
			return;
		mainActivity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				showKeyboardOnUiThread();
			}
		});
	}

	private static void showKeyboardOnUiThread()
	{
		if (mainContext == null || mainActivity == null)
			return;

		try
		{
			// Use SDL's own text-input machinery (DummyEdit + InputConnection).
			// This is the exact same path the game uses internally, so the soft
			// keyboard reliably appears on every device - hand-rolled EditText
			// probes were flaky on Android 15.
			org.libsdl.app.SDLActivity.showTextInput(0, 0, 0, 1, 1);
			keyboardShowing = true;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "showKeyboard: " + e.toString());
		}
	}

	public static void dismissKeyboard()
	{
		if (!keyboardShowing)
			return;
		if (mainActivity == null)
		{
			keyboardShowing = false;
			return;
		}
		mainActivity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				dismissKeyboardOnUiThread();
			}
		});
	}

	private static void dismissKeyboardOnUiThread()
	{
		keyboardShowing = false;
		try
		{
			if (mainContext != null && mainView != null)
			{
				InputMethodManager imm = (InputMethodManager) mainContext.getSystemService(Context.INPUT_METHOD_SERVICE);
				if (imm != null && mainView != null && mainView.getWindowToken() != null)
					imm.hideSoftInputFromWindow(mainView.getWindowToken(), 0);
			}
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "dismissKeyboard: " + e.toString());
		}
	}

	public static void setAutoShow(boolean value)
	{
		autoShow = value;
		savePrefs();
	}

	public static boolean getAutoShow()
	{
		return autoShow;
	}

	public static void setEnabled(boolean value)
	{
		enabled = value;
		savePrefs();
		if (!value)
			hide();
	}

	public static boolean getEnabled()
	{
		return enabled;
	}

	public static void toast(final String message)
	{
		try
		{
			if (mainActivity != null)
			{
				mainActivity.runOnUiThread(new Runnable()
				{
					@Override
					public void run()
					{
						Toast.makeText(mainContext, message, Toast.LENGTH_LONG).show();
					}
				});
			}
		}
		catch (Exception e) {}
	}

	/** Copy text into the system clipboard. Returns true on success. */
	public static boolean setClipboardText(String text)
	{
		try
		{
			if (mainContext == null || text == null)
				return false;
			ClipboardManager cm = (ClipboardManager) mainContext.getSystemService(Context.CLIPBOARD_SERVICE);
			if (cm == null)
				return false;
			cm.setPrimaryClip(ClipData.newPlainText("SeiunEngine", text));
			return true;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "setClipboardText: " + e.toString());
			return false;
		}
	}

	/**
	 * Called from the engine at startup: shows the button automatically when
	 * permission is granted, otherwise asks the user once to enable it.
	 */
	public static void maybeAutoShow()
	{
		loadPrefs();

		if (!enabled || !autoShow)
			return;

		// Just try to show; the permission prompt is handled by onResume()
		// (activity lifecycle) so it can't be missed during startup.
		if (isOverlayPermissionGranted())
			show();
	}

	// ------------------------------------------------------------------
	// Lifecycle (registered through <config:android extension>)
	// ------------------------------------------------------------------

	@Override
	public void onCreate(Bundle state)
	{
		super.onCreate(state);
		loadPrefs();
	}

	@Override
	public void onResume()
	{
		super.onResume();

		if (!enabled || !autoShow)
			return;

		if (isOverlayPermissionGranted())
		{
			if (!visible)
				show();
		}
		else if (!getPrefs().getBoolean("prompted", false))
		{
			getPrefs().edit().putBoolean("prompted", true).apply();
			mainActivity.runOnUiThread(new Runnable()
			{
				@Override
				public void run()
				{
					try
					{
						mainActivity.getWindow().getDecorView().postDelayed(new Runnable()
						{
							@Override
							public void run()
							{
								if (!isOverlayPermissionGranted())
									promptOverlayPermission();
							}
						}, 500);
					}
					catch (Exception e)
					{
						Log.e(LOG_TAG, "onResume prompt: " + e.toString());
					}
				}
			});
		}
	}

	@Override
	public void onPause()
	{
		super.onPause();
		dismissKeyboard();
	}

	@Override
	public void onDestroy()
	{
		super.onDestroy();
		hide();
	}

	// ------------------------------------------------------------------
	// Internals
	// ------------------------------------------------------------------

	private static void createButton()
	{
		try
		{
			final Context ctx = mainContext;

			button = new ImageView(ctx);
			button.setScaleType(ImageView.ScaleType.FIT_CENTER);
			button.setPadding(dp(11), dp(11), dp(11), dp(11));

			// Modern "floating ball": vertical gradient + soft border + shadow.
			GradientDrawable bg = new GradientDrawable();
			bg.setShape(GradientDrawable.RECTANGLE);
			bg.setCornerRadius(dp(26));
			bg.setGradientType(GradientDrawable.LINEAR_GRADIENT);
			bg.setOrientation(GradientDrawable.Orientation.TL_BR);
			bg.setColors(new int[] { 0xE63A3A5C, 0xE61A1A2E });
			bg.setStroke(dp(1), 0x55FFFFFF);
			button.setBackground(bg);

			// Soft shadow under the ball (API 21+ supports elevation).
			button.setElevation(dp(6));

			button.setImageBitmap(drawKeyboardIcon());

			button.setOnTouchListener(new View.OnTouchListener()
			{
				@Override
				public boolean onTouch(View v, MotionEvent event)
				{
					switch (event.getActionMasked())
					{
						case MotionEvent.ACTION_DOWN:
							// Press feedback: shrink slightly.
							v.animate().scaleX(0.88f).scaleY(0.88f).setDuration(80).start();
							downRawX = event.getRawX();
							downRawY = event.getRawY();
							if (overlayParams != null)
							{
								downWindowX = overlayParams.x;
								downWindowY = overlayParams.y;
							}
							dragging = false;
							downTime = System.currentTimeMillis();
							return true;

						case MotionEvent.ACTION_MOVE:
							if (overlayParams != null && windowManager != null)
							{
								float dx = event.getRawX() - downRawX;
								float dy = event.getRawY() - downRawY;
								if (!dragging && (Math.abs(dx) > dp(8) || Math.abs(dy) > dp(8)))
									dragging = true;
								if (dragging)
								{
									overlayParams.x = Math.round(downWindowX + dx);
									overlayParams.y = Math.round(downWindowY + dy);
									try
									{
										windowManager.updateViewLayout(button, overlayParams);
									}
									catch (Exception e) {}
								}
							}
							return true;

						case MotionEvent.ACTION_UP:
							v.animate().scaleX(1f).scaleY(1f).setDuration(100).start();
							if (!dragging)
							{
								long elapsed = System.currentTimeMillis() - downTime;
								if (elapsed < 600)
									toggleKeyboard();
							}
							else
							{
								savePosition();
							}
							dragging = false;
							return true;

						case MotionEvent.ACTION_CANCEL:
							v.animate().scaleX(1f).scaleY(1f).setDuration(100).start();
							dragging = false;
							return true;
					}
					return false;
				}
			});
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "createButton: " + e.toString());
			button = null;
		}
	}

	/** Draw a nicer Material-style keyboard glyph with shading. */
	private static Bitmap drawKeyboardIcon()
	{
		int s = dp(52);
		Bitmap bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
		Canvas canvas = new Canvas(bmp);
		Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
		p.setStyle(Paint.Style.FILL);

		float u = s / 24f;

		// Keyboard body with a subtle vertical gradient.
		android.graphics.LinearGradient bodyGrad = new android.graphics.LinearGradient(
			0, 5 * u, 0, 19 * u,
			0xFFF2F4FF, 0xFFC9CFE8,
			android.graphics.Shader.TileMode.CLAMP);
		p.setShader(bodyGrad);
		RectF body = new RectF(2 * u, 5 * u, 22 * u, 19 * u);
		canvas.drawRoundRect(body, 2 * u, 2 * u, p);
		p.setShader(null);

		// Key caps: rounded squares with a slightly darker shade.
		p.setColor(0xFF2A2E4A);
		float[][] keys = {
			{4, 8}, {8, 8}, {12, 8}, {16, 8},
			{4, 12}, {8, 12}, {12, 12}, {16, 12},
			{6, 16}, {10, 16}, {14, 16}
		};
		for (float[] k : keys)
		{
			RectF key = new RectF(k[0] * u, k[1] * u, (k[0] + 2) * u, (k[1] + 2) * u);
			canvas.drawRoundRect(key, 0.6f * u, 0.6f * u, p);
		}
		return bmp;
	}

	/** System dialog asking the user to grant "Display over other apps". */
	private static void promptOverlayPermission()
	{
		if (mainActivity == null)
			return;
		try
		{
			android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(mainActivity);
			builder.setTitle("Floating keyboard");
			builder.setMessage("SeiunEngine wants to show a floating keyboard button over other apps.\n\nPlease allow \"Display over other apps\" in the next screen.");
			builder.setCancelable(false);
			builder.setPositiveButton("Open Settings", new android.content.DialogInterface.OnClickListener()
			{
				@Override
				public void onClick(android.content.DialogInterface dialog, int which)
				{
					dialog.dismiss();
					requestOverlayPermission();
				}
			});
			builder.setNegativeButton("Not Now", new android.content.DialogInterface.OnClickListener()
			{
				@Override
				public void onClick(android.content.DialogInterface dialog, int which)
				{
					dialog.dismiss();
				}
			});
			builder.show();
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "promptOverlayPermission: " + e.toString());
			requestOverlayPermission();
		}
	}

	private static void removeKeyboardProbe()
	{
		if (keyboardProbe != null && mainView instanceof ViewGroup)
		{
			try
			{
				((ViewGroup) mainView).removeView(keyboardProbe);
			}
			catch (Exception e) {}
		}
		keyboardProbe = null;
	}

	private static int loadSavedX(int size)
	{
		SharedPreferences prefs = getPrefs();
		int defaultX = screenWidth() - size - dp(10);
		return prefs.getInt("x", defaultX);
	}

	private static int loadSavedY(int size)
	{
		SharedPreferences prefs = getPrefs();
		int defaultY = dp(56);
		return prefs.getInt("y", defaultY);
	}

	private static void savePosition()
	{
		if (overlayParams == null)
			return;
		try
		{
			SharedPreferences.Editor editor = getPrefs().edit();
			editor.putInt("x", overlayParams.x);
			editor.putInt("y", overlayParams.y);
			editor.apply();
		}
		catch (Exception e) {}
	}

	private static void loadPrefs()
	{
		try
		{
			SharedPreferences prefs = getPrefs();
			autoShow = prefs.getBoolean(KEY_AUTO_SHOW, true);
			enabled = prefs.getBoolean(KEY_ENABLED, true);
		}
		catch (Exception e) {}
	}

	private static void savePrefs()
	{
		try
		{
			SharedPreferences.Editor editor = getPrefs().edit();
			editor.putBoolean(KEY_AUTO_SHOW, autoShow);
			editor.putBoolean(KEY_ENABLED, enabled);
			editor.apply();
		}
		catch (Exception e) {}
	}

	private static SharedPreferences getPrefs()
	{
		return mainContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
	}

	private static int screenWidth()
	{
		try
		{
			android.util.DisplayMetrics dm = new android.util.DisplayMetrics();
			windowManager.getDefaultDisplay().getMetrics(dm);
			return dm.widthPixels;
		}
		catch (Exception e)
		{
			return 1280;
		}
	}

	private static int dp(int value)
	{
		try
		{
			if (mainContext != null)
			{
				return Math.round(TypedValue.applyDimension(
					TypedValue.COMPLEX_UNIT_DIP, value, mainContext.getResources().getDisplayMetrics()));
			}
		}
		catch (Exception e) {}
		return value;
	}
}
