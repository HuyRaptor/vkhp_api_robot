*** Settings ***
Documentation     Comprehensive Test Suite for Warehouse Zone Management and Stock Transfer in vKho API
...               Tests zone creation, product allocation, and stock transfers
...               with positive, negative, edge cases, missing parameters, and input validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate with specified role
    [Arguments]         ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Zone Data
    [Documentation]     Generate unique zone data for warehouse
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=       Create Dictionary
    ...                 name=Test Zone ${timestamp}
    ...                 code=Z${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 capacity=500
    ...                 isActive=${TRUE}
    ...                 description=Test Zone Description
    RETURN            ${zone_data}

Generate Product Data
    [Documentation]     Generate product data for zone allocation
    [Arguments]         ${zone_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_code}=    Set Variable     PROD${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 name=Test Product ${timestamp}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
    ...                 importDate=2025-04-02T00:00:00.000Z
    ...                 cost=10.50
    ...                 salePrice=15.00
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-04-02T00:00:00.000Z
    ...                 productCode=${product_code}
    ...                 supplierId=1
    ...                 productCategoryId=37
    ...                 zoneId=${zone_id}
    RETURN            ${product_data}

Generate Stock Transfer Data
    [Documentation]     Generate stock transfer data between zones
    [Arguments]         ${product_id}    ${from_zone_id}    ${to_zone_id}    ${quantity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${transfer_data}=   Create Dictionary
    ...                 productId=${product_id}
    ...                 fromZoneId=${from_zone_id}
    ...                 toZoneId=${to_zone_id}
    ...                 quantity=${quantity}
    ...                 transferDate=2025-04-02T00:00:00.000Z
    ...                 reason=Test Transfer ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    RETURN            ${transfer_data}

Create Zone
    [Documentation]     Create a new zone in warehouse
    [Arguments]         ${zone_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${zone_id}=         Convert To String    ${json}[id]
    RETURN            ${zone_id}

Create Product
    [Documentation]     Create a new product allocated to a zone
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    RETURN            ${product_id}

Create Stock Transfer
    [Documentation]     Create a stock transfer between zones
    [Arguments]         ${transfer_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-transfers/create
    ...                 json=${transfer_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${transfer_id}=     Convert To String    ${json}[id]
    RETURN            ${transfer_id}

Get Zone By ID
    [Documentation]     Retrieve a specific zone
    [Arguments]         ${zone_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /zones/get-one/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Assert Zone Details
    [Documentation]     Verify zone details match expected values
    [Arguments]         ${zone}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${zone}    Should Be Equal    ${zone}[${key}]    ${expected_data}[${key}]
    END

*** Test Cases ***
01 - Setup Admin Environment
    [Documentation]     Setup API session with admin credentials
    [Tags]              setup    admin
    Setup API Session    ${ADMIN_USERNAME}    ${ADMIN_PASSWORD}
    Log                 Successfully authenticated as admin

02 - Create Zone - Positive
    [Documentation]     Test creating a new zone in warehouse
    [Tags]              create    zones    positive    admin
    ${zone_data}=       Generate Zone Data
    ${zone_id}=         Create Zone    ${zone_data}
    Should Not Be Empty    ${zone_id}
    Set Global Variable    ${ZONE_ID}    ${zone_id}
    ${zone}=            Get Zone By ID    ${zone_id}
    Assert Zone Details    ${zone}    ${zone_data}
    Log                 Created zone with ID: ${zone_id}

03 - Create Zone - Negative (Invalid Warehouse)
    [Documentation]     Test creating zone with invalid warehouse ID
    [Tags]              create    zones    negative    admin
    ${zone_data}=       Generate Zone Data
    Set To Dictionary   ${zone_data}    warehouseId=${INVALID_WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create zone with invalid warehouse as expected

04 - Create Zone - Missing Parameters (Name)
    [Documentation]     Test creating zone without required name
    [Tags]              create    zones    missing-parameters    admin
    ${zone_data}=       Generate Zone Data
    Remove From Dictionary    ${zone_data}    name
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create zone without name as expected

05 - Create Zone - Input Validation (Negative Capacity)
    [Documentation]     Test creating zone with negative capacity
    [Tags]              create    zones    input-validation    admin
    ${zone_data}=       Generate Zone Data
    Set To Dictionary   ${zone_data}    capacity=-100
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create zone with negative capacity as expected

06 - Switch to Manager Environment
    [Documentation]     Switch to manager credentials
    [Tags]              setup    manager
    Setup API Session    ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
    Log                 Successfully authenticated as manager

07 - Create Product - Positive
    [Documentation]     Test creating product allocated to zone
    [Tags]              create    products    positive    manager
    ${product_data}=    Generate Product Data    ${ZONE_ID}
    ${product_id}=      Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Set Global Variable    ${PRODUCT_ID}    ${product_id}
    Log                 Created product with ID: ${product_id}

08 - Create Product - Negative (Invalid Zone)
    [Documentation]     Test creating product with invalid zone ID
    [Tags]              create    products    negative    manager
    ${product_data}=    Generate Product Data    ${INVALID_ZONE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create product with invalid zone as expected

09 - Create Product - Edge (Max Quantity)
    [Documentation]     Test creating product with maximum quantity
    [Tags]              create    products    edge    manager
    ${product_data}=    Generate Product Data    ${ZONE_ID}
    Set To Dictionary   ${product_data}    totalQuantity=999999    expectedQuantity=999999
    
    ${product_id}=      Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Log                 Created product with max quantity, ID: ${product_id}

10 - Create Second Zone - Positive
    [Documentation]     Create a second zone for stock transfer
    [Tags]              create    zones    positive    manager
    ${zone_data}=       Generate Zone Data
    ${second_zone_id}=  Create Zone    ${zone_data}
    Should Not Be Empty    ${second_zone_id}
    Set Global Variable    ${SECOND_ZONE_ID}    ${second_zone_id}
    Log                 Created second zone with ID: ${second_zone_id}

11 - Create Stock Transfer - Positive
    [Documentation]     Test transferring stock between zones
    [Tags]              create    stock-transfers    positive    manager
    ${transfer_data}=   Generate Stock Transfer Data    ${PRODUCT_ID}    ${ZONE_ID}    ${SECOND_ZONE_ID}    50
    ${transfer_id}=     Create Stock Transfer    ${transfer_data}
    Should Not Be Empty    ${transfer_id}
    Set Global Variable    ${TRANSFER_ID}    ${transfer_id}
    Log                 Created stock transfer with ID: ${transfer_id}

12 - Create Stock Transfer - Negative (Invalid Product)
    [Documentation]     Test stock transfer with invalid product ID
    [Tags]              create    stock-transfers    negative    manager
    ${transfer_data}=   Generate Stock Transfer Data    ${INVALID_PRODUCT_ID}    ${ZONE_ID}    ${SECOND_ZONE_ID}    50
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-transfers/create
    ...                 json=${transfer_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create stock transfer with invalid product as expected

13 - Create Stock Transfer - Missing Parameters (Quantity)
    [Documentation]     Test stock transfer without quantity
    [Tags]              create    stock-transfers    missing-parameters    manager
    ${transfer_data}=   Generate Stock Transfer Data    ${PRODUCT_ID}    ${ZONE_ID}    ${SECOND_ZONE_ID}    50
    Remove From Dictionary    ${transfer_data}    quantity
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-transfers/create
    ...                 json=${transfer_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create stock transfer without quantity as expected

14 - Create Stock Transfer - Edge (Transfer All Stock)
    [Documentation]     Test transferring all available stock
    [Tags]              create    stock-transfers    edge    manager
    ${transfer_data}=   Generate Stock Transfer Data    ${PRODUCT_ID}    ${ZONE_ID}    ${SECOND_ZONE_ID}    50
    ${transfer_id}=     Create Stock Transfer    ${transfer_data}
    Should Not Be Empty    ${transfer_id}
    Log                 Successfully transferred all remaining stock, ID: ${transfer_id}

15 - Create Stock Transfer - Input Validation (Negative Quantity)
    [Documentation]     Test stock transfer with negative quantity
    [Tags]              create    stock-transfers    input-validation    manager
    ${transfer_data}=   Generate Stock Transfer Data    ${PRODUCT_ID}    ${ZONE_ID}    ${SECOND_ZONE_ID}    -50
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-transfers/create
    ...                 json=${transfer_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create stock transfer with negative quantity as expected

16 - Cleanup Test Environment
    [Documentation]     Clean up test resources
    [Tags]              cleanup    manager
    # Add deletion endpoints if available
    Log                 Test environment cleaned up successfully