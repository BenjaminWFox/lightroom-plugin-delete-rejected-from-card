# Adobe Lightroom Classic Plugin: Delete Rejected From Card

This plugin scans a Lightroom folder (optionally it's child folders as well) to find all Rejected images. Then it scans some other folder (which you select) **AND** all of that folders child folders. For every filename found in this other folder which matches a rejected image filename found in the lightroom folder, the plugin deletes that image from the other (non-lightroom) folder. This does not delete (or do anything at all) to any of your photos in Lightroom.

## ⚠️ WARNING ⚠️ ##
**Full disclosure:** While I write software for a living, and I have tested this against my own cards/catalog, I do not know Lua and this was written by AI under my direction. 

***Use at your own risk***

## Plugin ##
There have been several posts over years asking about available of this feature:
- https://community.adobe.com/questions-675/delete-photo-s-on-sd-card-after-import-984339
- https://community.adobe.com/bug-reports-674/p-is-there-a-way-to-delete-just-unwanted-photos-off-memory-card-663709

It's particularly handy for travelers, who don't want a separate external drive to maintain a copy of all photos they want to keep while on an extended trip, and don't want to spend extra money on a wallet full of memory cards.

## Installation ##

#### 1️⃣ On this page, click the green 'Code' button, then click 'Download Zip', and unzip that file.####

<img width="1870" height="956" alt="Screenshot 2026-04-20 at 8 30 58 PM" src="https://github.com/user-attachments/assets/fc901548-bd08-45cb-bdda-cda8e1460eb6" />

#### 2️⃣ In Lightroom, go to the 'Plug-in Manager', click 'Add', then find the .lrplugin file from the unzipped package in the previous step. ####

<img width="1776" height="1126" alt="Screenshot 2026-04-20 at 8 35 05 PM" src="https://github.com/user-attachments/assets/c8255a98-f839-4420-ae26-8aa098ff6e7c" />

## Usage ##

#### 3️⃣ In Lightroom, go to Library > Plug-in Extras > Delete rejected from card ####

<img width="1088" height="589" alt="Screenshot-2026-04-20-at-8 37 45 PM-2" src="https://github.com/user-attachments/assets/bc74d85a-5bb7-477f-8baa-aa4592e421a7" />

#### 4️⃣ The plugin will walk you through a set of steps to select your LR Folder, External Folder, and confirm what it found before deleting ####
