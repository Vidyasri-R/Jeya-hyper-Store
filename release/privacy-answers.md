# Privacy & content forms — Jeya Hyper Store (customer app)

Answers for Google Play's **Data safety** and **App content** pages and Apple's **App Privacy** and
**Age rating**, matching what the app and backend actually do (site/privacy, backend, Razorpay SDK).
Re-check whenever we add push notifications, analytics, crash reporting or a new SDK.

## What the app collects

| Data | Why | Required? |
| --- | --- | --- |
| Phone number | Sign-in (OTP), order updates, delivery contact | Yes |
| Name | Shown on orders and to delivery staff | Yes |
| Email | Order details | Optional |
| Delivery addresses | Delivery, delivery charge | Yes, to order |
| Precise location | Only when the customer taps "use my location" to pin the address; no background location | Optional |
| Purchase history | Orders, refunds, GST records | Yes |
| Payment details (card / UPI / bank) | Entered in Razorpay's checkout inside the app; we never see card numbers | Only for online payment |

Not collected: contacts, photos, files, messages, calendar, health, device IDs or advertising ID,
analytics, crash logs, background location. No ads, no tracking, no data sold.

## Google Play — Data safety

- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes** (in the app: Profile →
  Delete account; on the web: https://jeyahyperstore.in/delete-account)

Data types (all: **Collected = yes, Shared = no**, processed ephemerally = no):

| Category → type | Required/optional | Purposes |
| --- | --- | --- |
| Personal info → Name | Required | App functionality, Account management |
| Personal info → Email address | Optional | App functionality, Account management |
| Personal info → Phone number | Required | App functionality, Account management, Fraud prevention & security |
| Personal info → Address | Required | App functionality |
| Location → Precise location | Optional | App functionality |
| Financial info → User payment info | Optional | App functionality |
| Financial info → Purchase history | Required | App functionality |

"Shared = no" is correct: Razorpay (payments) and our hosting providers process data on our behalf,
which Google counts as service providers, not sharing.

## Google Play — other App content pages

| Page | Answer |
| --- | --- |
| Privacy policy | https://jeyahyperstore.in/privacy |
| App access | Restricted. Instructions: "Sign in with phone 9999999999, OTP 123456." (turn on the store app's "App store reviewer login" first) |
| Ads | No ads |
| Content rating | Category "All other app types"; answer No to violence, sexual content, profanity, drugs, gambling; users don't interact or share content; no digital purchases. Expected rating: Everyone / 3+ |
| Target audience | 18 and over |
| News app | No |
| Government app | No |
| Financial features | My app doesn't provide any financial features |
| Health | No health features |
| Data safety | As above |

Content rating: if the store will sell tobacco products (cigarettes, beedi, paan masala) through the
app, say so in the questionnaire. It changes the rating, and Play and Apple restrict such listings.

## Apple — App Privacy

Data used to track you: **None**. Everything below is **Linked to the user**, purpose **App
Functionality** only, not used for tracking:

- Contact Info: Name, Email Address, Phone Number, Physical Address
- Location: Precise Location
- Financial Info: Payment Info (Razorpay checkout)
- Purchases: Purchase History

Everything else: not collected.

## Apple — Age rating

Answer "None" / "No" to every content question; no unrestricted web access, no user-generated
content, no gambling, no contests. Expected: **4+**. Same tobacco caveat as above.

## Apple — Export compliance

Already answered in the build (`ITSAppUsesNonExemptEncryption = NO`): the app only uses standard
HTTPS. App Store Connect won't ask on each upload.
