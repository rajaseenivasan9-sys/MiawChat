package com.newyorklife.mynyl.mobile

interface SalesforceAuthTokenProvider {
    suspend fun onGetToken(): String
    suspend fun onRefreshToken(): String
}
