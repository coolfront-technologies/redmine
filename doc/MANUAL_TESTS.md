# Redmine Manual Test Document

This document provides manual test scenarios covering all major functional areas
of the Redmine project management application.

---

## Table of Contents

1. [Authentication & Account Management](#1-authentication--account-management)
2. [My Page & My Account](#2-my-page--my-account)
3. [Project Management](#3-project-management)
4. [Issue Tracking](#4-issue-tracking)
5. [Time Logging](#5-time-logging)
6. [Wiki](#6-wiki)
7. [News](#7-news)
8. [Forums & Boards](#8-forums--boards)
9. [Documents](#9-documents)
10. [Files](#10-files)
11. [Calendar](#11-calendar)
12. [Gantt Chart](#12-gantt-chart)
13. [Repository / Source Control](#13-repository--source-control)
14. [Search](#14-search)
15. [Activity Feed](#15-activity-feed)
16. [Reports](#16-reports)
17. [Watchers](#17-watchers)
18. [Administration – Users & Groups](#18-administration--users--groups)
19. [Administration – Roles & Permissions](#19-administration--roles--permissions)
20. [Administration – Trackers](#20-administration--trackers)
21. [Administration – Issue Statuses](#21-administration--issue-statuses)
22. [Administration – Workflows](#22-administration--workflows)
23. [Administration – Custom Fields](#23-administration--custom-fields)
24. [Administration – Enumerations](#24-administration--enumerations)
25. [Administration – Settings](#25-administration--settings)
26. [Administration – LDAP Authentication](#26-administration--ldap-authentication)
27. [Administration – Plugins](#27-administration--plugins)
28. [API Access](#28-api-access)

---

## Legend

| Symbol | Meaning            |
|--------|--------------------|
| ✅     | Expected pass      |
| Pre    | Precondition       |
| Steps  | Test steps         |
| Exp    | Expected result    |

---

## 1. Authentication & Account Management

### TC-AUTH-001 – Successful Login with Valid Credentials

**Pre:** A user account exists with login `jsmith` and password `jsmith`.

**Steps:**
1. Navigate to `/login`.
2. Enter username `jsmith` and password `jsmith`.
3. Click **Sign in**.

**Exp:** User is redirected to **My Page**. The top navigation shows the username `John Smith`.

---

### TC-AUTH-002 – Failed Login with Invalid Credentials

**Pre:** No user with login `baduser` exists (or password is wrong).

**Steps:**
1. Navigate to `/login`.
2. Enter username `baduser` and password `wrongpass`.
3. Click **Sign in**.

**Exp:** The login page reloads with the error *"Invalid user or password"*. The user remains unauthenticated.

---

### TC-AUTH-003 – Logout

**Pre:** User is logged in.

**Steps:**
1. Click the user name in the top-right corner.
2. Click **Sign out**.

**Exp:** User is redirected to the home/welcome page and is no longer authenticated.

---

### TC-AUTH-004 – Self-Registration (Email Activation)

**Pre:** Administration → Settings → Authentication has *Self-registration* set to **"Email activation"**.

**Steps:**
1. Navigate to `/register`.
2. Fill in all required fields (login, first name, last name, e-mail, password, password confirmation).
3. Click **Submit**.

**Exp:** A message indicates an activation email has been sent. The user cannot log in until the activation link is clicked.

---

### TC-AUTH-005 – Self-Registration (Automatic Activation)

**Pre:** Self-registration is set to **"Automatic activation"**.

**Steps:**
1. Navigate to `/register` and fill in required fields.
2. Click **Submit**.

**Exp:** User is automatically logged in and redirected to **My Account**.

---

### TC-AUTH-006 – Self-Registration (Manual Administrator Approval)

**Pre:** Self-registration is set to **"Manual activation"**.

**Steps:**
1. Navigate to `/register` and complete the form.
2. Click **Submit**.

**Exp:** A message is shown stating the account is pending activation by an administrator. An email notification is sent to administrators.

---

### TC-AUTH-007 – Email Activation via Token

**Pre:** A registered-but-unactivated user exists; the activation token is known.

**Steps:**
1. Open the activation URL `/account/activate?token=<token>`.

**Exp:** The account is activated and the user is redirected to the sign-in page with a success notice.

---

### TC-AUTH-008 – Lost Password Recovery

**Pre:** User `jsmith` has email `jsmith@example.com`. Lost-password feature is enabled.

**Steps:**
1. Navigate to `/lost_password`.
2. Enter `jsmith@example.com` and click **Submit**.

**Exp:** A message confirms the email was sent. The user receives an email with a reset link.

---

### TC-AUTH-009 – Password Reset via Token

**Pre:** A valid password-recovery token was issued for user `jsmith`.

**Steps:**
1. Open the reset URL `/lost_password?token=<token>`.
2. Enter a new password and confirm it.
3. Click **Apply**.

**Exp:** Password is updated and user is redirected to the sign-in page with a success notice.

---

### TC-AUTH-010 – Auto-Login Cookie

**Pre:** Auto-login is enabled in Administration → Settings → Authentication.

**Steps:**
1. Navigate to `/login`.
2. Check the **Remember me** checkbox.
3. Log in successfully.
4. Close and reopen the browser.
5. Navigate to the application URL.

**Exp:** The user is automatically signed in without re-entering credentials.

---

## 2. My Page & My Account

### TC-MY-001 – View My Page

**Pre:** User is logged in.

**Steps:**
1. Click **My page** in the top navigation.

**Exp:** The "My Page" dashboard is displayed with configured blocks (e.g., issues, calendar).

---

### TC-MY-002 – Add Block to My Page

**Pre:** User is on My Page.

**Steps:**
1. Click **Personalize this page**.
2. Select a block to add (e.g., **Latest news**) from the dropdown and click **Add**.
3. Click **Back to My Page**.

**Exp:** The selected block now appears on the My Page dashboard.

---

### TC-MY-003 – Remove Block from My Page

**Pre:** My Page has at least one block.

**Steps:**
1. Click **Personalize this page**.
2. Click the **X** (remove) icon next to a block.
3. Click **Back to My Page**.

**Exp:** The removed block no longer appears on My Page.

---

### TC-MY-004 – Reorder Blocks on My Page

**Pre:** My Page has at least two blocks.

**Steps:**
1. Click **Personalize this page**.
2. Drag a block from one column to a different position.
3. Click **Back to My Page**.

**Exp:** Blocks are displayed in the updated order.

---

### TC-MY-005 – Edit My Account

**Pre:** User is logged in.

**Steps:**
1. Click the username → **My account**.
2. Change the **First name** field.
3. Click **Save**.

**Exp:** The account is updated; the new first name appears in the profile.

---

### TC-MY-006 – Change Password from My Account

**Pre:** User uses internal Redmine authentication.

**Steps:**
1. Go to **My account** → **Change password**.
2. Enter the current password and a new password (with confirmation).
3. Click **Apply**.

**Exp:** A success notice is displayed; user can now log in with the new password.

---

### TC-MY-007 – Generate RSS Key

**Pre:** RSS feeds are enabled in Administration → Settings.

**Steps:**
1. Go to **My account**.
2. Click **Reset** next to **RSS access key**.

**Exp:** A new RSS key is generated and displayed.

---

### TC-MY-008 – Generate API Access Key

**Pre:** REST API is enabled.

**Steps:**
1. Go to **My account**.
2. Click **Reset** next to **API access key**.

**Exp:** A new API key is generated and displayed.

---

## 3. Project Management

### TC-PROJ-001 – Create a New Public Project

**Pre:** User has the **Create project** privilege.

**Steps:**
1. Click **Projects** → **New project**.
2. Fill in **Name** (e.g., `Test Project`), **Identifier** (e.g., `test-project`).
3. Check **Public** and at least one module (e.g., Issue tracking, Wiki).
4. Click **Create**.

**Exp:** Project is created and the Overview page is shown.

---

### TC-PROJ-002 – Create a Private Project

**Pre:** Same as TC-PROJ-001.

**Steps:**
1. Create a project without checking **Public**.

**Exp:** Project is created. It is not visible to non-members.

---

### TC-PROJ-003 – Edit Project Settings

**Pre:** A project exists; user is a project manager.

**Steps:**
1. Go to the project → **Settings**.
2. Change the **Description**.
3. Click **Save**.

**Exp:** Changes are saved and displayed on the project overview.

---

### TC-PROJ-004 – Enable / Disable Project Modules

**Pre:** Project exists.

**Steps:**
1. Go to project → **Settings** → **Modules**.
2. Uncheck **Wiki** and click **Save**.

**Exp:** The **Wiki** tab disappears from the project navigation.

---

### TC-PROJ-005 – Manage Project Members

**Pre:** Project exists; a user to add exists.

**Steps:**
1. Go to project → **Settings** → **Members**.
2. Click **New member**.
3. Select a user and a role (e.g., **Developer**). Click **Add**.

**Exp:** The user appears in the members list with the selected role.

---

### TC-PROJ-006 – Remove a Project Member

**Pre:** A member exists in the project.

**Steps:**
1. Go to project → **Settings** → **Members**.
2. Click **Delete** next to the member.

**Exp:** The member is removed and no longer listed.

---

### TC-PROJ-007 – Manage Project Versions

**Pre:** Project exists.

**Steps:**
1. Go to project → **Settings** → **Versions** → **New version**.
2. Enter a version name (e.g., `v1.0`) and click **Create**.

**Exp:** The version appears in the versions list.

---

### TC-PROJ-008 – Manage Issue Categories

**Pre:** Project exists.

**Steps:**
1. Go to project → **Settings** → **Issue categories** → **New category**.
2. Enter a name (e.g., `Backend`) and click **Create**.

**Exp:** The category appears in the issue categories list.

---

### TC-PROJ-009 – Copy a Project

**Pre:** A source project exists with issues and wiki content.

**Steps:**
1. Go to Administration → Projects.
2. Click **Copy** next to the source project.
3. Fill in the new project identifier and select items to copy.
4. Click **Copy**.

**Exp:** A new project is created containing the selected items.

---

### TC-PROJ-010 – Archive a Project

**Pre:** A non-archived project exists.

**Steps:**
1. Go to Administration → Projects.
2. Click **Archive** next to the project.
3. Confirm the action.

**Exp:** The project is archived and is no longer accessible to regular users.

---

### TC-PROJ-011 – Unarchive a Project

**Pre:** An archived project exists.

**Steps:**
1. In Administration → Projects, ensure the **Status** filter shows archived projects.
2. Click **Unarchive** next to the archived project.

**Exp:** The project becomes active again.

---

### TC-PROJ-012 – Close a Project

**Pre:** An active project exists.

**Steps:**
1. Go to project → **Settings** → click **Close** (or use the admin projects list).

**Exp:** Project status changes to "closed"; no new issues can be created.

---

### TC-PROJ-013 – Delete a Project

**Pre:** An unneeded project exists (only test data).

**Steps:**
1. Go to Administration → Projects.
2. Click **Delete** next to the project and confirm.

**Exp:** The project and all its data are permanently deleted.

---

## 4. Issue Tracking

### TC-ISSUE-001 – Create a New Issue

**Pre:** User has the **Add issues** permission in the project.

**Steps:**
1. Navigate to the project → **Issues** → **New issue**.
2. Select a tracker (e.g., `Bug`), enter a **Subject**, set **Priority**.
3. Click **Create**.

**Exp:** Issue is created and its detail page is displayed with the assigned issue number.

---

### TC-ISSUE-002 – Create Issue with All Fields

**Pre:** Custom fields, categories, and versions exist.

**Steps:**
1. Create a new issue and fill all available fields: Description, Assignee, Category, Target version, Start date, Due date, Estimated hours, Done %, watchers.
2. Click **Create**.

**Exp:** All field values are saved and displayed on the issue detail page.

---

### TC-ISSUE-003 – Edit an Existing Issue

**Pre:** An issue exists; user has **Edit issues** permission.

**Steps:**
1. Open an issue.
2. Click **Edit**.
3. Change the **Subject** and add a **Note** in the journal.
4. Click **Submit**.

**Exp:** The issue subject is updated. A journal entry with the note and change details appears.

---

### TC-ISSUE-004 – Change Issue Status

**Pre:** A workflow allows status transitions for the current user's role.

**Steps:**
1. Open an issue.
2. Click **Edit** → change **Status** (e.g., from `New` to `In Progress`).
3. Click **Submit**.

**Exp:** Issue status updates; the change is recorded in the journal.

---

### TC-ISSUE-005 – Assign Issue to a User

**Pre:** Issue exists; project has members.

**Steps:**
1. Open an issue → **Edit**.
2. Change **Assigned to** to another user.
3. Click **Submit**.

**Exp:** The assignee changes; the journal records the update.

---

### TC-ISSUE-006 – Add Attachment to Issue

**Pre:** Issue exists; file attachments are enabled.

**Steps:**
1. Open an issue → **Edit**.
2. Click **Choose file** under Attachments and select a file.
3. Click **Submit**.

**Exp:** The attachment appears in the issue's Attachments section.

---

### TC-ISSUE-007 – Download an Attachment

**Pre:** An issue has an attachment.

**Steps:**
1. Open the issue.
2. Click the attachment filename.

**Exp:** The file is downloaded.

---

### TC-ISSUE-008 – Delete an Attachment

**Pre:** An issue has an attachment; user has delete-attachment permission.

**Steps:**
1. Open the issue → **Edit**.
2. Check **Delete** next to the attachment.
3. Click **Submit**.

**Exp:** The attachment is removed.

---

### TC-ISSUE-009 – Add Related Issue (Relation)

**Pre:** At least two issues exist in the project.

**Steps:**
1. Open an issue → **Relations** tab → click **Add**.
2. Select a relation type (e.g., `blocks`) and enter the related issue number.
3. Click **Add**.

**Exp:** The relation appears in the **Relations** section.

---

### TC-ISSUE-010 – Delete an Issue Relation

**Pre:** An issue has a relation.

**Steps:**
1. Open the issue with the relation.
2. Click **Delete** (×) next to the relation.

**Exp:** The relation is removed.

---

### TC-ISSUE-011 – Bulk Edit Issues

**Pre:** Multiple issues exist.

**Steps:**
1. Go to the issue list → select two or more issues using checkboxes.
2. Click **Edit** in the context menu or **Bulk edit**.
3. Change **Priority** to `High` and click **Submit**.

**Exp:** All selected issues have their priority changed to `High`.

---

### TC-ISSUE-012 – Bulk Deletion of Issues

**Pre:** Multiple test issues exist.

**Steps:**
1. Select two or more issues in the issue list.
2. Click **Delete** in the context menu and confirm.

**Exp:** All selected issues are permanently deleted.

---

### TC-ISSUE-013 – Filter Issues

**Pre:** Issues with different statuses and priorities exist.

**Steps:**
1. Go to the issue list.
2. Add a filter **Status** = `Open` and **Priority** = `High`.
3. Apply the filters.

**Exp:** Only issues matching the filter criteria are displayed.

---

### TC-ISSUE-014 – Save a Custom Query

**Pre:** User is on the issue list with filters applied.

**Steps:**
1. After applying filters, click **Save**.
2. Enter a name for the query and click **Save**.

**Exp:** The saved query appears in the left panel and can be reused.

---

### TC-ISSUE-015 – Export Issues to CSV

**Pre:** Issues exist.

**Steps:**
1. Go to the issue list.
2. Click **Export** → **CSV**.

**Exp:** A CSV file is downloaded containing the listed issues.

---

### TC-ISSUE-016 – Export Issues to PDF

**Pre:** Issues exist.

**Steps:**
1. Go to the issue list.
2. Click **Export** → **PDF**.

**Exp:** A PDF file is downloaded listing the issues.

---

### TC-ISSUE-017 – View Issue as Atom Feed

**Pre:** RSS access is enabled.

**Steps:**
1. Go to the issue list.
2. Click the **Atom** feed icon or append `.atom` to the URL.

**Exp:** The Atom/RSS feed is returned with the issues.

---

### TC-ISSUE-018 – Set Parent Issue (Sub-task)

**Pre:** Multiple issues exist.

**Steps:**
1. Open an issue → **Edit**.
2. Enter a parent issue number in the **Parent task** field.
3. Click **Submit**.

**Exp:** The parent-child relationship is shown on both issues.

---

### TC-ISSUE-019 – Navigate Previous / Next Issue

**Pre:** Multiple issues exist in a filtered list.

**Steps:**
1. Open an issue from the issue list.
2. Use the **Previous** / **Next** navigation links at the top.

**Exp:** The adjacent issue from the list is displayed.

---

## 5. Time Logging

### TC-TIME-001 – Log Time on an Issue

**Pre:** User has **Log time** permission; Time tracking module is enabled.

**Steps:**
1. Open an issue.
2. Click **Log time**.
3. Enter **Date**, **Hours** (e.g., `2.5`), and select an **Activity**.
4. Click **Create**.

**Exp:** Time entry is saved; the spent time total on the issue increases.

---

### TC-TIME-002 – Edit a Time Entry

**Pre:** A time entry exists.

**Steps:**
1. Go to the project → **Spent time**.
2. Click **Edit** next to a time entry.
3. Change the hours value and click **Save**.

**Exp:** The time entry is updated.

---

### TC-TIME-003 – Delete a Time Entry

**Pre:** A time entry exists.

**Steps:**
1. Go to the project → **Spent time**.
2. Click **Delete** next to a time entry and confirm.

**Exp:** The time entry is deleted.

---

### TC-TIME-004 – Bulk Edit Time Entries

**Pre:** Multiple time entries exist.

**Steps:**
1. Go to **Spent time** list.
2. Select multiple time entries.
3. Click **Edit** → change the activity and click **Submit**.

**Exp:** All selected entries have the activity updated.

---

### TC-TIME-005 – Time Log Report

**Pre:** Time entries exist in the project.

**Steps:**
1. Go to project → **Spent time** → **Report**.
2. Select grouping criteria (e.g., by user, by activity).

**Exp:** The report displays aggregated time data according to the selected grouping.

---

### TC-TIME-006 – Log Time from My Page

**Pre:** Time log block or global timelog is accessible.

**Steps:**
1. Go to **My page**.
2. If available, click **Log time** from the global menu.
3. Select a project/issue, fill in hours, and save.

**Exp:** The time entry is created and visible in the project's Spent time list.

---

## 6. Wiki

### TC-WIKI-001 – View Wiki Start Page

**Pre:** Wiki module is enabled; a start page exists.

**Steps:**
1. Navigate to a project → **Wiki**.

**Exp:** The wiki start page content is displayed.

---

### TC-WIKI-002 – Create a New Wiki Page

**Pre:** User has **Edit wiki pages** permission.

**Steps:**
1. Navigate to the wiki and type a new page URL (e.g., `/projects/test/wiki/NewPage`).
2. Click **Edit this page** and enter content using Textile or Markdown.
3. Click **Save**.

**Exp:** The new page is created and displayed with the entered content.

---

### TC-WIKI-003 – Edit an Existing Wiki Page

**Pre:** A wiki page exists.

**Steps:**
1. Open the wiki page.
2. Click **Edit**.
3. Modify the content.
4. Add a comment in the **Comment** field and click **Save**.

**Exp:** The page content is updated. The edit is recorded in the history.

---

### TC-WIKI-004 – View Wiki Page History

**Pre:** A wiki page has been edited more than once.

**Steps:**
1. Open the wiki page → click **History**.

**Exp:** A list of versions is shown with timestamps and authors.

---

### TC-WIKI-005 – Diff Between Wiki Versions

**Pre:** A wiki page has at least two versions.

**Steps:**
1. Open the wiki **History** for a page.
2. Select two versions and click **View differences**.

**Exp:** The diff view highlights additions (green) and deletions (red).

---

### TC-WIKI-006 – Annotate a Wiki Page

**Pre:** A wiki page has multiple versions by different authors.

**Steps:**
1. Open the wiki **History** → click **Annotate** on a version.

**Exp:** The annotated view shows which version each line was last changed in.

---

### TC-WIKI-007 – Rename a Wiki Page

**Pre:** User has **Rename wiki pages** permission.

**Steps:**
1. Open a wiki page.
2. Click **Rename**.
3. Enter a new name and click **Rename**.

**Exp:** The page is renamed and a redirect is automatically created from the old name.

---

### TC-WIKI-008 – Protect a Wiki Page

**Pre:** User has **Protect wiki pages** permission.

**Steps:**
1. Open a wiki page.
2. Click **Lock Page**.

**Exp:** Only users with the **Edit protected wiki pages** permission can edit the page.

---

### TC-WIKI-009 – Add Attachment to Wiki Page

**Pre:** User has edit permission.

**Steps:**
1. Open a wiki page → **Edit**.
2. Attach a file under the Attachments section.
3. Click **Save**.

**Exp:** The attachment is listed at the bottom of the wiki page.

---

### TC-WIKI-010 – Delete a Wiki Page

**Pre:** User has **Delete wiki pages** permission.

**Steps:**
1. Open a wiki page → click **Delete**.
2. Confirm the deletion.

**Exp:** The page is deleted; navigating to it returns a 404 or a "page not found" message.

---

### TC-WIKI-011 – Export Wiki to HTML

**Pre:** Wiki has pages with content.

**Steps:**
1. Navigate to the project wiki index.
2. Click **Export** → choose **HTML**.

**Exp:** An HTML export file is downloaded.

---

### TC-WIKI-012 – View Wiki Index (Date Index)

**Pre:** Multiple wiki pages exist.

**Steps:**
1. Navigate to the wiki.
2. Click **Index** (page index) or the date-based index link.

**Exp:** All wiki pages are listed alphabetically or by date.

---

## 7. News

### TC-NEWS-001 – Create a News Article

**Pre:** User has **Manage news** permission; News module is enabled.

**Steps:**
1. Navigate to project → **News** → **Add news**.
2. Fill in **Title**, **Summary**, and **Description**.
3. Click **Add**.

**Exp:** The news article is created and appears on the News page.

---

### TC-NEWS-002 – Edit a News Article

**Pre:** A news article exists.

**Steps:**
1. Go to project → **News**.
2. Click **Edit** next to the article.
3. Change the title and click **Save**.

**Exp:** The updated title is displayed.

---

### TC-NEWS-003 – Comment on a News Article

**Pre:** Comments are enabled; user has the **Comment news** permission.

**Steps:**
1. Open a news article.
2. Enter a comment in the **Comment** box and click **Add**.

**Exp:** The comment is displayed beneath the article.

---

### TC-NEWS-004 – Delete a News Article

**Pre:** User has the appropriate permission.

**Steps:**
1. Go to project → **News**.
2. Click **Delete** next to the article and confirm.

**Exp:** The article is permanently deleted.

---

## 8. Forums & Boards

### TC-BOARD-001 – Create a Forum Board

**Pre:** User has **Manage boards** permission.

**Steps:**
1. Go to project → **Settings** → **Forums** → **New forum**.
2. Enter a name and description.
3. Click **Create**.

**Exp:** The forum board is created and listed under the Forums tab.

---

### TC-BOARD-002 – Create a New Topic

**Pre:** A forum board exists; user has **Add messages** permission.

**Steps:**
1. Navigate to project → **Forums** → select a board.
2. Click **New topic**.
3. Enter a **Subject** and **Content**.
4. Click **Create**.

**Exp:** The topic is created and listed in the board.

---

### TC-BOARD-003 – Reply to a Topic

**Pre:** A forum topic exists.

**Steps:**
1. Open a topic.
2. Click **Quote** or **Reply**.
3. Enter a reply and click **Submit**.

**Exp:** The reply is appended to the topic thread.

---

### TC-BOARD-004 – Edit a Forum Message

**Pre:** User is the message author or has the edit permission.

**Steps:**
1. Open a forum message.
2. Click **Edit**.
3. Modify the content and click **Save**.

**Exp:** The message content is updated.

---

### TC-BOARD-005 – Delete a Forum Message

**Pre:** User has the **Delete messages** permission.

**Steps:**
1. Open a forum message.
2. Click **Delete** and confirm.

**Exp:** The message is deleted.

---

### TC-BOARD-006 – Edit a Board (Forum Settings)

**Pre:** User has **Manage boards** permission.

**Steps:**
1. Go to project → **Settings** → **Forums**.
2. Click **Edit** next to a board.
3. Change the description and click **Save**.

**Exp:** Changes are saved.

---

### TC-BOARD-007 – Delete a Board

**Pre:** A board exists.

**Steps:**
1. Go to project → **Settings** → **Forums**.
2. Click **Delete** next to the board and confirm.

**Exp:** The board and all its topics are deleted.

---

## 9. Documents

### TC-DOC-001 – Create a Document

**Pre:** User has **Manage documents** permission; Documents module is enabled.

**Steps:**
1. Go to project → **Documents** → **New document**.
2. Select a **Category**, enter a **Title** and **Description**.
3. Optionally attach a file.
4. Click **Save**.

**Exp:** The document is created and appears in the Documents list.

---

### TC-DOC-002 – Edit a Document

**Pre:** A document exists.

**Steps:**
1. Open a document.
2. Click **Edit**.
3. Change the title and click **Save**.

**Exp:** The document title is updated.

---

### TC-DOC-003 – Add Attachment to Document

**Pre:** A document exists.

**Steps:**
1. Open the document → **Edit**.
2. Attach a file and click **Save**.

**Exp:** The attachment is listed in the document.

---

### TC-DOC-004 – Delete a Document

**Pre:** A document exists.

**Steps:**
1. Go to the Documents list.
2. Click **Delete** next to the document and confirm.

**Exp:** The document is permanently deleted.

---

## 10. Files

### TC-FILE-001 – Upload a File to a Version

**Pre:** A project version exists; Files module is enabled.

**Steps:**
1. Go to project → **Files** → **Add**.
2. Select a **Version**, choose a file, and click **Add**.

**Exp:** The file appears in the Files list under the selected version.

---

### TC-FILE-002 – Download a File

**Pre:** A file exists in the Files section.

**Steps:**
1. Go to project → **Files**.
2. Click the file name.

**Exp:** The file is downloaded.

---

## 11. Calendar

### TC-CAL-001 – View Project Calendar

**Pre:** Issues with due dates exist.

**Steps:**
1. Navigate to project → **Calendar**.

**Exp:** The current month is shown; issues and versions with due dates appear on their respective days.

---

### TC-CAL-002 – Navigate Calendar Months

**Pre:** Issues in multiple months exist.

**Steps:**
1. Open the calendar.
2. Click the **>** (next month) arrow.

**Exp:** The calendar advances to the next month.

---

## 12. Gantt Chart

### TC-GANTT-001 – View Project Gantt Chart

**Pre:** Issues with start and due dates exist.

**Steps:**
1. Navigate to project → **Gantt**.

**Exp:** A Gantt chart is displayed with horizontal bars representing issue date ranges.

---

### TC-GANTT-002 – Zoom In / Out on Gantt

**Pre:** Gantt chart is displayed.

**Steps:**
1. Click the **+** zoom in button.
2. Click the **−** zoom out button.

**Exp:** The Gantt chart adjusts its time scale accordingly.

---

### TC-GANTT-003 – Export Gantt to PDF

**Pre:** Gantt chart is displayed.

**Steps:**
1. Click **Export** → **PDF**.

**Exp:** A PDF file of the Gantt chart is downloaded.

---

## 13. Repository / Source Control

### TC-REPO-001 – Create a Repository

**Pre:** User is a project admin; Repository module is enabled; a supported VCS (e.g., SVN, Git) is available.

**Steps:**
1. Go to project → **Settings** → **Repository** → **New repository**.
2. Select the SCM type and enter the URL.
3. Click **Create**.

**Exp:** The repository is configured and the Repository tab is accessible.

---

### TC-REPO-002 – Browse Repository Root

**Pre:** A repository is configured and accessible.

**Steps:**
1. Navigate to project → **Repository**.

**Exp:** The root directory listing of the repository is displayed.

---

### TC-REPO-003 – Browse a File Entry

**Pre:** Repository has files.

**Steps:**
1. In the repository browser, navigate to a file.
2. Click the file name.

**Exp:** The file content is displayed with syntax highlighting.

---

### TC-REPO-004 – View Revision History

**Pre:** Repository has commits.

**Steps:**
1. Go to project → **Repository** → **Revisions**.

**Exp:** A list of commits/revisions is displayed with author, date, and commit message.

---

### TC-REPO-005 – View a Diff Between Revisions

**Pre:** At least two revisions exist.

**Steps:**
1. Go to **Repository** → **Revisions**.
2. Click a revision to view the diff.

**Exp:** The diff view shows changed lines highlighted in red (removed) and green (added).

---

### TC-REPO-006 – View Revision Statistics (Graphs)

**Pre:** Repository has multiple commits.

**Steps:**
1. Go to project → **Repository** → **Statistics**.

**Exp:** Graphs showing commits per month and commits per author are displayed.

---

### TC-REPO-007 – Fetch Changesets

**Pre:** New commits have been pushed to the VCS after the last fetch.

**Steps:**
1. Go to Administration → Repositories (or use the API endpoint).
2. Trigger **Fetch changesets** for the project.

**Exp:** New revisions are imported and visible in the Repository → Revisions list.

---

### TC-REPO-008 – Associate a Changeset with an Issue

**Pre:** Issue exists; repository is configured; commit message contains `Fixes #<issue_number>`.

**Steps:**
1. Commit code with message `Fixes #1` to the repository.
2. Fetch changesets.
3. Open issue #1.

**Exp:** The changeset appears in the **Associated revisions** section of the issue.

---

### TC-REPO-009 – Annotate a File (Blame View)

**Pre:** A file exists with multiple revisions.

**Steps:**
1. Navigate to the file in the repository browser.
2. Click **Annotate**.

**Exp:** Each line is annotated with the revision and author that last modified it.

---

## 14. Search

### TC-SEARCH-001 – Global Search

**Pre:** Issues, wiki pages, and news articles exist.

**Steps:**
1. Enter a keyword in the search box at the top of the page.
2. Press **Enter** or click the search button.

**Exp:** Results are shown from all enabled scopes (issues, wiki, news, etc.).

---

### TC-SEARCH-002 – Search Scoped to a Project

**Pre:** Currently viewing a project.

**Steps:**
1. Enter a keyword in the search box.
2. Ensure **Search in current project** is checked.
3. Click **Search**.

**Exp:** Results are limited to the current project.

---

### TC-SEARCH-003 – Search by Specific Scope

**Pre:** Various content types exist.

**Steps:**
1. Perform a search.
2. On the results page, uncheck all scopes except **Issues** and click **Search**.

**Exp:** Only issue results are returned.

---

## 15. Activity Feed

### TC-ACTIVITY-001 – View Project Activity

**Pre:** Issues, wiki edits, and time entries exist.

**Steps:**
1. Navigate to project → **Activity**.

**Exp:** A chronological list of recent activities is displayed.

---

### TC-ACTIVITY-002 – Filter Activity by Type

**Pre:** Different types of activities exist.

**Steps:**
1. On the Activity page, uncheck all types except **Issues** and click **Apply**.

**Exp:** Only issue-related activities are shown.

---

### TC-ACTIVITY-003 – View Activity as Atom Feed

**Pre:** Activity feed access is enabled.

**Steps:**
1. Navigate to the Activity page.
2. Click the **Atom** icon or open the feed URL.

**Exp:** An Atom feed of the project activity is returned.

---

## 16. Reports

### TC-REPORT-001 – Issue Summary Report

**Pre:** Issues exist in various states and categories.

**Steps:**
1. Navigate to project → **Issues** → **Summary**.

**Exp:** A table showing issues grouped by tracker, status, and priority is displayed.

---

### TC-REPORT-002 – Time Entry Report (Cross-Project)

**Pre:** Time entries exist across multiple projects; user has access.

**Steps:**
1. Go to the top-level **Spent time** link (Administration or global menu).
2. Apply grouping by **Project** and **User**.

**Exp:** A report is displayed with hours grouped by project and user.

---

## 17. Watchers

### TC-WATCH-001 – Watch an Issue

**Pre:** User is logged in; an issue exists.

**Steps:**
1. Open an issue.
2. Click **Watch** in the sidebar.

**Exp:** The user is added to the watchers list and will receive email notifications for updates.

---

### TC-WATCH-002 – Unwatch an Issue

**Pre:** User is watching an issue.

**Steps:**
1. Open the watched issue.
2. Click **Unwatch**.

**Exp:** The user is removed from the watchers list.

---

### TC-WATCH-003 – Add Another User as a Watcher

**Pre:** User has **Add watchers** permission.

**Steps:**
1. Open an issue → **Edit**.
2. In the **Watchers** section, select a user and click **Add**.
3. Click **Submit**.

**Exp:** The selected user is added as a watcher.

---

## 18. Administration – Users & Groups

### TC-ADMIN-USER-001 – Create a New User

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Users → **New user**.
2. Fill in login, first name, last name, email, password.
3. Set **Status** to `Active`.
4. Click **Create**.

**Exp:** The user is created and appears in the Users list.

---

### TC-ADMIN-USER-002 – Edit a User

**Pre:** A user account exists.

**Steps:**
1. Go to Administration → Users.
2. Click a user name.
3. Change the email address.
4. Click **Save**.

**Exp:** The email address is updated.

---

### TC-ADMIN-USER-003 – Activate / Deactivate a User

**Pre:** A user account exists.

**Steps:**
1. Go to Administration → Users.
2. Click the user → change **Status** to `Locked` and save.

**Exp:** The user can no longer log in.

---

### TC-ADMIN-USER-004 – Delete a User

**Pre:** A disposable test user exists.

**Steps:**
1. Go to Administration → Users.
2. Click the user → click **Delete** and confirm.

**Exp:** The user is deleted.

---

### TC-ADMIN-USER-005 – Create a Group

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Groups → **New group**.
2. Enter a group name and click **Create**.

**Exp:** The group is created.

---

### TC-ADMIN-USER-006 – Add Users to a Group

**Pre:** A group and at least one user exist.

**Steps:**
1. Go to Administration → Groups → click a group.
2. In the **Users** tab, select users and click **Add users**.

**Exp:** The selected users appear in the group's member list.

---

### TC-ADMIN-USER-007 – Add Group as Project Member

**Pre:** A group and a project exist.

**Steps:**
1. Go to project → **Settings** → **Members** → **New member**.
2. Select the group and a role, then click **Add**.

**Exp:** All users in the group are treated as project members with the selected role.

---

## 19. Administration – Roles & Permissions

### TC-ROLE-001 – Create a New Role

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Roles and permissions → **New role**.
2. Enter a name (e.g., `Tester`) and configure permissions.
3. Click **Create**.

**Exp:** The role is created and available for assignment.

---

### TC-ROLE-002 – Edit Role Permissions

**Pre:** A role exists.

**Steps:**
1. Go to Administration → Roles and permissions.
2. Click a role name.
3. Check/uncheck permissions and click **Save**.

**Exp:** The permissions are updated.

---

### TC-ROLE-003 – Delete a Role

**Pre:** A role is not assigned to any project member.

**Steps:**
1. Go to Administration → Roles and permissions.
2. Click **Delete** next to the role and confirm.

**Exp:** The role is deleted.

---

## 20. Administration – Trackers

### TC-TRACKER-001 – Create a Tracker

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Trackers → **New tracker**.
2. Enter a name (e.g., `Task`), configure default status.
3. Click **Create**.

**Exp:** The tracker is created and appears in the tracker list.

---

### TC-TRACKER-002 – Edit a Tracker

**Pre:** A tracker exists.

**Steps:**
1. Go to Administration → Trackers.
2. Click a tracker name.
3. Change the name or default status and click **Save**.

**Exp:** Changes are saved.

---

### TC-TRACKER-003 – Add Tracker to a Project

**Pre:** A tracker and a project exist.

**Steps:**
1. Go to project → **Settings** → **Information**.
2. Check the tracker checkbox and click **Save**.

**Exp:** The tracker is available when creating issues in the project.

---

### TC-TRACKER-004 – Delete a Tracker

**Pre:** The tracker is not used by any issue.

**Steps:**
1. Go to Administration → Trackers.
2. Click **Delete** next to the tracker and confirm.

**Exp:** The tracker is deleted.

---

## 21. Administration – Issue Statuses

### TC-STATUS-001 – Create an Issue Status

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Issue statuses → **New status**.
2. Enter a name (e.g., `Pending Review`), optionally mark as closed.
3. Click **Create**.

**Exp:** The status is created.

---

### TC-STATUS-002 – Edit an Issue Status

**Pre:** A status exists.

**Steps:**
1. Go to Administration → Issue statuses.
2. Click a status name, change it and click **Save**.

**Exp:** Changes are saved.

---

### TC-STATUS-003 – Delete an Issue Status

**Pre:** The status is not referenced by any issue or workflow.

**Steps:**
1. Go to Administration → Issue statuses.
2. Click **Delete** next to the status and confirm.

**Exp:** The status is deleted.

---

## 22. Administration – Workflows

### TC-WORKFLOW-001 – Define Allowed Status Transitions

**Pre:** Trackers, roles, and statuses exist.

**Steps:**
1. Go to Administration → Workflows.
2. Select a **Tracker** (e.g., `Bug`) and a **Role** (e.g., `Developer`).
3. Click **Edit**.
4. Enable the transition from `New` → `In Progress` and click **Save**.

**Exp:** The transition is saved. A developer can change a Bug from `New` to `In Progress`.

---

### TC-WORKFLOW-002 – Copy Workflow Between Roles

**Pre:** A workflow is defined for one role.

**Steps:**
1. Go to Administration → Workflows → **Copy**.
2. Select the source role/tracker and the target role/tracker.
3. Click **Copy**.

**Exp:** The workflow is duplicated for the target role/tracker.

---

### TC-WORKFLOW-003 – Define Field Permissions in Workflow

**Pre:** Tracker and role exist.

**Steps:**
1. Go to Administration → Workflows → **Fields permissions** tab.
2. Select tracker and role; mark a field (e.g., **Priority**) as read-only for a status.
3. Click **Save**.

**Exp:** When a developer edits an issue with that status, the Priority field is read-only.

---

## 23. Administration – Custom Fields

### TC-CF-001 – Create a Custom Field for Issues

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Custom fields → **Issues** → **New custom field**.
2. Select type **Text**, enter a name (e.g., `Build Version`).
3. Assign it to one or more trackers.
4. Click **Save**.

**Exp:** The custom field appears on the issue form for the selected trackers.

---

### TC-CF-002 – Create a Required Custom Field

**Pre:** Custom field management is available.

**Steps:**
1. Create a custom field with **Required** checked.

**Exp:** Attempting to create an issue without filling in the field shows a validation error.

---

### TC-CF-003 – Create a Custom Field for Users

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Custom fields → **Users** → **New custom field**.
2. Select type **List** and enter possible values.
3. Click **Save**.

**Exp:** The custom field appears on the user profile form.

---

### TC-CF-004 – Delete a Custom Field

**Pre:** A custom field exists with no critical data.

**Steps:**
1. Go to Administration → Custom fields.
2. Click **Delete** next to the field and confirm.

**Exp:** The field is deleted and no longer appears on forms.

---

## 24. Administration – Enumerations

### TC-ENUM-001 – Create an Issue Priority

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Enumerations → **Issue priorities** → **New value**.
2. Enter a name (e.g., `Critical`) and check **Default** if desired.
3. Click **Create**.

**Exp:** The new priority is available when creating or editing issues.

---

### TC-ENUM-002 – Create a Time Entry Activity

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Enumerations → **Activities (time tracking)** → **New value**.
2. Enter a name (e.g., `Testing`).
3. Click **Create**.

**Exp:** The activity is available when logging time.

---

### TC-ENUM-003 – Create a Document Category

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Enumerations → **Document categories** → **New value**.
2. Enter a name (e.g., `Technical Specs`).
3. Click **Create**.

**Exp:** The category is available when creating documents.

---

### TC-ENUM-004 – Delete an Enumeration Value

**Pre:** An enumeration value is not in use.

**Steps:**
1. Go to Administration → Enumerations.
2. Click **Delete** next to the value and confirm.

**Exp:** The value is removed.

---

## 25. Administration – Settings

### TC-SETTINGS-001 – Change Application Title

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Settings → **General** tab.
2. Change the **Application title** and click **Save**.

**Exp:** The new title appears in the browser tab and application header.

---

### TC-SETTINGS-002 – Enable / Disable Self-Registration

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Settings → **Authentication**.
2. Change **Self-registration** value and click **Save**.

**Exp:** The registration link on the login page appears or disappears accordingly.

---

### TC-SETTINGS-003 – Send Test Email

**Pre:** Email settings are configured.

**Steps:**
1. Go to Administration → Settings → **Email notifications**.
2. Click **Send a test email**.

**Exp:** A test email is sent to the administrator's address and a success message is shown.

---

### TC-SETTINGS-004 – Change Default Language

**Pre:** Multiple language packs are installed.

**Steps:**
1. Go to Administration → Settings → **Display** tab.
2. Change **Default language** and click **Save**.

**Exp:** The UI language changes for users who have not set a personal language preference.

---

### TC-SETTINGS-005 – Enable REST API

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Settings → **API**.
2. Enable **Enable REST web service** and click **Save**.

**Exp:** The REST API becomes accessible.

---

## 26. Administration – LDAP Authentication

### TC-LDAP-001 – Create an LDAP Authentication Source

**Pre:** An LDAP server is accessible.

**Steps:**
1. Go to Administration → LDAP authentication → **New authentication source**.
2. Fill in LDAP host, port, base DN, and LDAP attributes mapping.
3. Click **Create**.

**Exp:** The LDAP source is created.

---

### TC-LDAP-002 – Test LDAP Connection

**Pre:** An LDAP source exists.

**Steps:**
1. Go to Administration → LDAP authentication.
2. Click **Test** next to the LDAP source.

**Exp:** A success message is shown if the connection is successful.

---

### TC-LDAP-003 – Authenticate User via LDAP

**Pre:** LDAP source is configured; user account exists in LDAP directory.

**Steps:**
1. Log in with LDAP credentials on the sign-in page.

**Exp:** User is authenticated and either logged in or asked to complete registration (if on-the-fly account creation is enabled).

---

## 27. Administration – Plugins

### TC-PLUGIN-001 – View Installed Plugins

**Pre:** Administrator is logged in.

**Steps:**
1. Go to Administration → Plugins.

**Exp:** A list of installed plugins is displayed with their version and description.

---

## 28. API Access

### TC-API-001 – Retrieve Issue List via REST API

**Pre:** REST API is enabled; a valid API key is available.

**Steps:**
1. Send `GET /issues.json?key=<api_key>` (or use Basic Auth).

**Exp:** A JSON response is returned containing the issues list.

---

### TC-API-002 – Create Issue via REST API

**Pre:** REST API is enabled; API key has sufficient privileges.

**Steps:**
1. Send `POST /issues.json` with headers `Content-Type: application/json` and body:
   ```json
   {
     "issue": {
       "project_id": 1,
       "subject": "API Test Issue",
       "tracker_id": 1
     }
   }
   ```

**Exp:** HTTP `201 Created` is returned; the new issue appears in the project.

---

### TC-API-003 – Update Issue via REST API

**Pre:** An issue exists; API key is valid.

**Steps:**
1. Send `PUT /issues/<id>.json` with a JSON body changing the subject.

**Exp:** HTTP `200 OK` (or `204 No Content`) is returned; the issue subject is updated.

---

### TC-API-004 – Delete Issue via REST API

**Pre:** An issue exists; API key has delete permission.

**Steps:**
1. Send `DELETE /issues/<id>.json`.

**Exp:** HTTP `200 OK` (or `204 No Content`) is returned; the issue is deleted.

---

### TC-API-005 – Retrieve Project List via REST API

**Pre:** REST API is enabled.

**Steps:**
1. Send `GET /projects.json?key=<api_key>`.

**Exp:** A JSON response is returned listing accessible projects.

---

### TC-API-006 – Retrieve Time Entries via REST API

**Pre:** Time entries exist; REST API is enabled.

**Steps:**
1. Send `GET /time_entries.json?key=<api_key>`.

**Exp:** A JSON response lists the time entries.

---

### TC-API-007 – Invalid API Key Returns 401

**Pre:** REST API is enabled.

**Steps:**
1. Send `GET /issues.json?key=invalidkey`.

**Exp:** HTTP `401 Unauthorized` is returned.

---

### TC-API-008 – Atom Feed for Issues

**Pre:** RSS feeds are enabled; an RSS key is available.

**Steps:**
1. Navigate to `/issues.atom?key=<rss_key>` (or access the feed URL from the issue list page).

**Exp:** A valid Atom/RSS XML document is returned with the issues.

---

*End of Manual Test Document*
