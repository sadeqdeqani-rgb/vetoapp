<?php

return [

    'telegram' => [
        'bot_token' => env('TELEGRAM_BOT_TOKEN'),
        'bot_username' => env('TELEGRAM_BOT_USERNAME'),
        'webhook_secret' => env('TELEGRAM_WEBHOOK_SECRET'),
        'timeout' => (int) env('TELEGRAM_HTTP_TIMEOUT', 10),
    ],

    'process_receipts' => [
        'key_id' => env('PROCESS_RECEIPT_KEY_ID'),
        'private_key' => env('PROCESS_RECEIPT_PRIVATE_KEY'),
        'public_key' => env('PROCESS_RECEIPT_PUBLIC_KEY'),
        'identity_hmac_key' => env('PROCESS_IDENTITY_HMAC_KEY'),
    ],
    'process_tree_heads' => [
        'key_id' => env('PROCESS_TREE_HEAD_KEY_ID'),
        'private_key' => env('PROCESS_TREE_HEAD_PRIVATE_KEY'),
        'public_key' => env('PROCESS_TREE_HEAD_PUBLIC_KEY'),
    ],
    'activation_requests' => [
        'hmac_key' => env('ACTIVATION_REQUEST_HMAC_KEY', env('APP_KEY')),
    ],
    'apple_device_check' => [
        'team_id' => env('APPLE_DEVICECHECK_TEAM_ID'),
        'key_id' => env('APPLE_DEVICECHECK_KEY_ID'),
        'private_key' => env('APPLE_DEVICECHECK_PRIVATE_KEY'),
        'environment' => env('APPLE_DEVICECHECK_ENVIRONMENT', 'production'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
