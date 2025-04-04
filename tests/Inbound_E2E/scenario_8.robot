*** Settings ***
Documentation     Comprehensive Test Suite for Receipt Operations with Product Orders in vKho API
...               Includes product management, master products, replenishments, and package handling with product order constraints
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session As Admin
    [Documentation]     Create API session and authenticate as admin
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${ADMIN_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Setup API Session As Manager
    [Documentation]     Create API session and authenticate as manager
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
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    ${timestamp}=       Get Time    epoch
    ${sku}=             Set Variable    SKU${timestamp}
    ${name}=            Set Variable    Test Product ${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 sku=${sku}
    ...                 name=${name}
    ...                 description=Test Product Description
    ...                 unit=PIECE
    ...                 status=${PRODUCT_STATUS_ENABLE}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    RETURN            ${product_data}

Create Product
    [Documentation]     Create a new product
    [Arguments]         ${product_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${product_data}    sku
    ...    msg=Missing required field: sku
    Dictionary Should Contain Key    ${product_data}    name
    ...    msg=Missing required field: name
    Dictionary Should Contain Key    ${product_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Generate Unique Product Order Data
    [Documentation]     Generate unique data for product order tests
    [Arguments]         ${product_id}
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    PO${timestamp}
    
    ${product_order}=   Create Dictionary
    ...                 productId=${product_id}
    ...                 quantity=10
    ...                 unitPrice=100
    ...                 total=1000
    
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${PRODUCT_ORDER_STATUS_NEW}
    ...                 note=Test Product Order Note
    ...                 productOrders=${product_orders}
    
    RETURN            ${order_data}

Create Product Order
    [Documentation]     Create a new product order
    [Arguments]         ${order_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required field: code
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    Dictionary Should Contain Key    ${order_data}    productOrders
    ...    msg=Missing required field: productOrders
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Get Product Order By ID
    [Documentation]     Retrieve a specific product order by ID
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}    msg=Product Order ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Update Product Order
    [Documentation]     Update an existing product order
    [Arguments]         ${order_id}    ${update_data}
    
    Should Not Be Empty    ${order_id}    msg=Product Order ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${order_id}
    ...    msg=Update data ID must match order_id parameter
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /product-orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Delete Product Order
    [Documentation]     Delete a product order
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}    msg=Product Order ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /product-orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Generate Unique Receipt Data
    [Documentation]     Generate unique data for receipt tests
    [Arguments]         ${product_order_id}
    
    ${timestamp}=       Get Time    epoch
    ${receipt_code}=    Set Variable    RCP${timestamp}
    
    ${receipt_data}=    Create Dictionary
    ...                 code=${receipt_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${RECEIPT_STATUS_NEW}
    ...                 note=Test Receipt Note
    ...                 productOrderId=${product_order_id}
    
    RETURN            ${receipt_data}

Create Receipt
    [Documentation]     Create a new receipt
    [Arguments]         ${receipt_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${receipt_data}    code
    ...    msg=Missing required field: code
    Dictionary Should Contain Key    ${receipt_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    Dictionary Should Contain Key    ${receipt_data}    productOrderId
    ...    msg=Missing required field: productOrderId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /receipts/create
    ...                 json=${receipt_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Get Receipt By ID
    [Documentation]     Retrieve a specific receipt by ID
    [Arguments]         ${receipt_id}
    
    Should Not Be Empty    ${receipt_id}    msg=Receipt ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /receipts/get-one/${receipt_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Update Receipt
    [Documentation]     Update an existing receipt
    [Arguments]         ${receipt_id}    ${update_data}
    
    Should Not Be Empty    ${receipt_id}    msg=Receipt ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${receipt_id}
    ...    msg=Update data ID must match receipt_id parameter
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /receipts/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Delete Receipt
    [Documentation]     Delete a receipt
    [Arguments]         ${receipt_id}
    
    Should Not Be Empty    ${receipt_id}    msg=Receipt ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /receipts/delete/${receipt_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Create Package
    [Documentation]     Create a new package
    [Arguments]         ${package_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${package_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Get Package By ID
    [Documentation]     Retrieve a specific package by ID
    [Arguments]         ${package_id}
    
    Should Not Be Empty    ${package_id}    msg=Package ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-one/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Update Package
    [Documentation]     Update an existing package
    [Arguments]         ${package_id}    ${update_data}
    
    Should Not Be Empty    ${package_id}    msg=Package ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${package_id}
    ...    msg=Update data ID must match package_id parameter
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /packages/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Delete Package
    [Documentation]     Delete a package
    [Arguments]         ${package_id}
    
    Should Not Be Empty    ${package_id}    msg=Package ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API sessions for both admin and manager
    [Tags]              setup
    Setup API Session As Admin
    Setup API Session As Manager
    Log                 Successfully authenticated as both admin and manager

02 - Create Product Test
    [Documentation]     Test creating a new product
    [Tags]              product    create    positive
    
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[sku]    ${product_data}[sku]
    
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    
    Log                 Successfully created product: ${response}[name] with ID: ${TEST_PRODUCT_ID}

03 - Create Product Order Test
    [Documentation]     Test creating a new product order with product constraints
    [Tags]              order    create    positive
    
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Product Test
    
    ${order_data}=      Generate Unique Product Order Data    ${TEST_PRODUCT_ID}
    ${order_id}    ${response}=    Create Product Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    
    Set Global Variable  ${TEST_PRODUCT_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_PRODUCT_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created product order: ${response}[code] with ID: ${TEST_PRODUCT_ORDER_ID}

04 - Create Receipt Test
    [Documentation]     Test creating a new receipt linked to product order
    [Tags]              receipt    create    positive
    
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Product Order Test
    
    ${receipt_data}=    Generate Unique Receipt Data    ${TEST_PRODUCT_ORDER_ID}
    ${receipt_id}    ${response}=    Create Receipt    ${receipt_data}
    
    Should Not Be Empty    ${receipt_id}
    Should Be Equal     ${response}[code]    ${receipt_data}[code]
    Should Be Equal     ${response}[productOrderId]    ${TEST_PRODUCT_ORDER_ID}
    
    Set Global Variable  ${TEST_RECEIPT_ID}      ${receipt_id}
    Set Global Variable  ${TEST_RECEIPT_DATA}    ${receipt_data}
    
    Log                 Successfully created receipt: ${response}[code] with ID: ${TEST_RECEIPT_ID}

05 - Create Package Test
    [Documentation]     Test creating a new package
    [Tags]              package    create    positive
    
    ${package_data}=    Create Dictionary
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${PACKAGE_STATUS_NEW}
    ...                 note=Test Package Note
    ...                 receiptId=${TEST_RECEIPT_ID}
    
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    Should Not Be Empty    ${package_id}
    Should Be Equal     ${response}[warehouseId]    ${WAREHOUSE_ID}
    Should Be Equal     ${response}[receiptId]    ${TEST_RECEIPT_ID}
    
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}
    
    Log                 Successfully created package with ID: ${TEST_PACKAGE_ID}

06 - Update Product Order Test
    [Documentation]     Test updating an existing product order
    [Tags]              order    update    positive
    
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Product Order Test
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PRODUCT_ORDER_ID}
    ...                 status=${PRODUCT_ORDER_STATUS_PENDING}
    ...                 note=Updated Product Order Note
    
    ${updated_order}=    Update Product Order    ${TEST_PRODUCT_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    ${PRODUCT_ORDER_STATUS_PENDING}
    
    Log                 Successfully updated product order: ${TEST_PRODUCT_ORDER_ID}

07 - Update Receipt Test
    [Documentation]     Test updating an existing receipt
    [Tags]              receipt    update    positive
    
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Receipt Test
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_RECEIPT_ID}
    ...                 status=${RECEIPT_STATUS_PENDING}
    ...                 note=Updated Receipt Note
    
    ${updated_receipt}=    Update Receipt    ${TEST_RECEIPT_ID}    ${update_data}
    Should Be Equal     ${updated_receipt}[status]    ${RECEIPT_STATUS_PENDING}
    
    Log                 Successfully updated receipt: ${TEST_RECEIPT_ID}

08 - Update Package Test
    [Documentation]     Test updating an existing package
    [Tags]              package    update    positive
    
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Package Test
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PACKAGE_ID}
    ...                 status=${PACKAGE_STATUS_PENDING}
    ...                 note=Updated Package Note
    
    ${updated_package}=    Update Package    ${TEST_PACKAGE_ID}    ${update_data}
    Should Be Equal     ${updated_package}[status]    ${PACKAGE_STATUS_PENDING}
    
    Log                 Successfully updated package: ${TEST_PACKAGE_ID}

09 - Verify Product Order and Receipt Integration Test
    [Documentation]     Test verifying product order and receipt integration
    [Tags]              integration    positive
    
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Product Order Test
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Receipt Test
    
    ${order}=           Get Product Order By ID    ${TEST_PRODUCT_ORDER_ID}
    ${receipt}=         Get Receipt By ID    ${TEST_RECEIPT_ID}
    
    Should Be Equal     ${order}[warehouseId]    ${receipt}[warehouseId]
    ...    msg=Product order and receipt warehouse IDs do not match
    Should Be Equal     ${receipt}[productOrderId]    ${TEST_PRODUCT_ORDER_ID}
    ...    msg=Receipt is not linked to the correct product order
    
    Log                 Successfully verified product order and receipt integration

10 - Verify Receipt and Package Integration Test
    [Documentation]     Test verifying receipt and package integration
    [Tags]              integration    positive
    
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Receipt Test
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Package Test
    
    ${receipt}=         Get Receipt By ID    ${TEST_RECEIPT_ID}
    ${package}=         Get Package By ID    ${TEST_PACKAGE_ID}
    
    Should Be Equal     ${receipt}[warehouseId]    ${package}[warehouseId]
    ...    msg=Receipt and package warehouse IDs do not match
    Should Be Equal     ${package}[receiptId]    ${TEST_RECEIPT_ID}
    ...    msg=Package is not linked to the correct receipt
    
    Log                 Successfully verified receipt and package integration

11 - Cleanup Test Environment
    [Documentation]     Clean up all test resources
    [Tags]              cleanup
    
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 Delete Package    ${TEST_PACKAGE_ID}
    Run Keyword If      "${TEST_RECEIPT_ID}" != "${EMPTY}"
    ...                 Delete Receipt    ${TEST_RECEIPT_ID}
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Product Order    ${TEST_PRODUCT_ORDER_ID}
    Run Keyword If      "${TEST_PRODUCT_ID}" != "${EMPTY}"
    ...                 Delete Product    ${TEST_PRODUCT_ID}
    
    Log                 Test environment cleaned up successfully
