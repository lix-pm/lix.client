package lix.client;

typedef SchemeHandler = { url:String, tmpLoc:String, target:LibUrl }->Promise<Downloaded>;
