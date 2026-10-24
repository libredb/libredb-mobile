# LibreDB Mobile privacy policy

Last updated: October 24, 2026.

This policy describes what LibreDB Mobile for Android does with your data.
LibreDB Mobile is a client of LibreDB Studio: it signs you in through Keycloak and shows the databases that Studio offers you.
Questions about this policy go to [info@libredb.org](mailto:info@libredb.org).

## The servers the app talks to

The app talks to three kinds of servers, and to no others on its own:

- **Keycloak**, the sign-in server of the LibreDB deployment the app was built for.
  You sign in on Keycloak's own page, in the device's browser, so the app never sees your password.
  Keycloak gives the app tokens that identify you.
- **LibreDB Studio** of the same deployment.
  The app sends Studio your Keycloak access token with its requests, so Studio knows who you are and what you may use.
  The access token carries what Keycloak puts into it, such as your username, your e-mail address and your name.
  The app also sends Studio what you ask it to do: the connection you open, the objects you look at and the statements you run.
- **Sentry**, a crash reporting service, but only when the build was made with a Sentry project key.
  See the Crash reports section below.

The organisation that runs the deployment operates Keycloak and Studio, and decides what they record.
For example, Studio can keep an audit log of sign-ins and sign-outs and, depending on its settings, a record of the statements you run.
That organisation's own privacy terms cover what those servers keep.

The app reaches Keycloak, Studio and Sentry over HTTPS, which encrypts the traffic.

## What the app does not do

- The app holds no database password or other database credential: Studio keeps them and opens every database connection.
- The app shows no advertising, contains no advertising, third-party analytics or tracking SDK, and sends nothing about how you use it beyond the crash reports, session records and timing information described in the Crash reports section below.
- The app does not read your contacts, location, photos, files or other apps' data.
- The app does not sell your data or share it with anyone for advertising.

## What the app keeps on the device

- **Your session tokens**, in Android's secure storage, encrypted with a key held by the Android Keystore.
  Signing out deletes them.
- **Your drafts and statement history**: the editor's draft for each connection and the statements you ran, encrypted on the device with a key for your account alone.
  They stay after you sign out, so you find them again when you sign in with the same account, and another account on the device cannot read them.
- **Your connection choices**: the connections you starred or opened recently, the connection you had open last and the database you last used on it, and the sections of the connection list you collapsed.
- **Device preferences**: the language, the theme and whether results show as cards or as a table.

The app keeps no rows of query results after it closes.
While it runs, it keeps the lists, counts and descriptions of a connection's objects in memory for up to 10 minutes, so going back does not ask Studio again.
What you type into the object search goes only to Studio, and the app keeps no search history.
Android's cloud backup is turned off for the app, and its preferences, drafts and history are left out of device-to-device transfers.

## Sharing and copying

The app passes data to another app only when you ask it to.
When you copy a value of a result, the app copies what the screen shows, so a masked value is copied as its mask.
When you share an object's source, such as a view's definition, the system's share sheet sends it to the app you choose.
A source longer than 100,000 characters is shared as a file, and that file can stay in the app's temporary storage until Android clears it or you uninstall the app.

## Crash reports

A build made with a Sentry project key sends a report to Sentry when the app runs into an error.
A report holds the error and where in the app it happened, the app's version, technical details of the device such as its model, Android version, language, free memory and battery level, a random identifier of the installation, and a trail of the events before the error, such as the screens you opened and the app going to the background.
A build with a Sentry project key also sends a session record each time you use the app: when the session started and ended, how long it lasted, whether it ended in a crash, and the installation identifier.
It also sends timing information for about one in five app starts and screen changes, to show where the app is slow.
Before a report leaves the device, the app removes e-mail addresses, tokens, passwords and other credentials from it.
A report carries no screenshot, no layout of the screen, no request body and no screen recording of the session.
Sentry receives your device's IP address with each report, as with any connection to a server.
Sentry derives an approximate location, such as a city and a country, from that address, unless the Sentry project is set not to store IP addresses.
A build made without a Sentry project key sends no reports.

## Protections on the device

- The screens that show query results, a row's detail, a key's value or an object's source are kept out of screenshots, screen recordings and the recent apps view.
- Columns whose names look sensitive, such as e-mail, password or card number, are masked on screen.
- The app signs you out after 15 minutes without input.

## Deleting your data

- **Remove my data**, in the Privacy section of Settings, deletes what the app keeps for the signed-in account (the drafts, the history and the connection choices) and then signs you out.
  It keeps the language, the theme and the result view preference, which belong to the device.
- **Uninstalling the app** deletes everything it keeps on the device.
- Crash reports already sent stay in Sentry until they expire; write to [info@libredb.org](mailto:info@libredb.org) to have them deleted sooner.
- Data that Keycloak or Studio keep about you is held by the organisation that runs them; ask that organisation to delete it.

## Children

The app is a tool for people who work with databases and is not directed at children.

## Changes to this policy

When the app starts handling data in a new way, this policy is updated before that version is released, and the date at the top changes.
