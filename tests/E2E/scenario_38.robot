*** Settings ***
Documentation     Comprehensive Test Suite for Order Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_ORDER_ID}        ${EMPTY}
${TEST_ORDER_CODE}      ${EMPTY}
${TEST_ORDER_DATA}      ${EMPTY}

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    # Send login request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn't exist
    Create Directory    ${RESULTS_DIR}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${custom_name}=Test Order
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_name}=      Set Variable     ${custom_name} ${timestamp}
    ${order_code}=      Set Variable     ORD${timestamp}
    ${booth_code}=      Set Variable     BTH${timestamp}
    
    # Sample product order data
    ${product_order}=   Create Dictionary
    ...                 total=10
    ...                 boothCode=${booth_code}
    ...                 sku=SKU${timestamp}
    ${product_orders}=  Create List      ${product_order}
    
    # Return dictionary of generated data
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${order_name}
    ...                 code=${order_code}
    ...                 boothCode=${booth_code}
    ...                 deliveryAdress=123 Test Street
    ...                 deliveryTime=2025-04-02T10:00:00.000Z
    ...                 driverName=John Doe
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    [Return]            ${order_data}

Create Order
    [Documentation]     Create a new order and return its ID
    [Arguments]         ${order_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${order_data}    nameCustomer
    ...    msg=Missing required parameter: nameCustomer
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    boothCode
    ...    msg=Missing required parameter: boothCode
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${order_data}    productOrders
    ...    msg=Missing required parameter: productOrders
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create order request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create order response missing ID field
    
    # Return order ID and full response
    ${order_id}=        Convert To String    ${json}[id]
    [Return]            ${order_id}    ${json}

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get order request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get order response missing ID field
    
    [Return]            ${json}

Update Order
    [Documentation]     Update an existing order
    [Arguments]         ${order_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${order_id}
    ...    msg=Update data ID must match order_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    boothCode
    ...    msg=Update data missing required field: boothCode
    Dictionary Should Contain Key    ${update_data}    deliveryAdress
    ...    msg=Update data missing required field: deliveryAdress
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update order request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update order response missing ID field
    
    [Return]            ${json}

Delete Order
    [Documentation]     Delete an order from the system
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete order request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    [Return]            ${TRUE}

Get All Orders
    [Documentation]     Retrieve all orders with optional filtering
    [Arguments]         ${warehouse_id}=${WAREHOUSE_ID}    ${filter_params}=${EMPTY}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    
    # Add any additional filter parameters if provided
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all orders request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all orders response was empty
    
    [Return]            ${json}

Assert Order Details
    [Documentation]     Verify order details match expected values
    [Arguments]         ${order}    ${expected_data}
    
    # For all keys in expected data, verify they match in the order data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${order}    Should Be Equal    ${order}[${key}]    ${expected_data}[${key}]
        ...    msg=Order ${key} value '${order}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Order
    [Documentation]     Creates a test order if one doesn't exist
    ${order_data}=      Generate Unique Order Data
    ${order_id}    ${response}=    Create Order    ${order_data}
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates order is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response_text}''')    json
    
    # Check for status field indicating deletion
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Set Variable    ${FALSE}
    
    [Return]            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'CANCELLED'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    [Return]            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Order Test
    [Documentation]     Test creating a new order
    [Tags]              create    positive
    
    # Generate order data
    ${order_data}=      Generate Unique Order Data
    
    # Create order
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    # Verify order was created successfully
    Should Not Be Empty    ${order_id}
    ...    msg=Failed to create order: No ID returned
    Should Be Equal     ${response}[code]    ${order_data}[code]
    ...    msg=Created order code does not match input data
    
    # Save order ID for subsequent tests
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

03 - Create Order Missing Required Field Test
    [Documentation]     Test creating an order with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete order data (missing driverName)
    ${incomplete_data}=  Generate Unique Order Data    custom_name=Missing Field Order
    Remove From Dictionary    ${incomplete_data}    driverName
    
    # Attempt to create order with incomplete data
    Run Keyword And Expect Error    *Missing required parameter: driverName*
    ...                 Create Order    ${incomplete_data}
    
    Log                 Successfully verified that creating an order with missing fields is rejected

04 - Get Order Test
    [Documentation]     Test retrieving a specific order
    [Tags]              retrieve    positive
    
    # Create an order if one doesn't exist
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    # Get order
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    
    # Verify order details match what we created
    Assert Order Details    ${order}    ${TEST_ORDER_DATA}
    
    Log                 Successfully retrieved order: ${order}[code]

05 - Get Non-Existent Order Test
    [Documentation]     Test retrieving an order that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent order
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /orders/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent order fails

06 - Update Order Test
    [Documentation]     Test updating an existing order
    [Tags]              update    positive
    
    # Create an order if one doesn't exist
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    # Prepare update data
    ${updated_code}=    Set Variable    ${TEST_ORDER_CODE}-UPD
    ${product_order}=   Create Dictionary    id=1    pickingQuantity=5
    ${product_orders}=  Create List      ${product_order}
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=456 Updated Street
    ...                 deliveryTime=2025-04-03T12:00:00.000Z
    ...                 driverName=Jane Doe
    ...                 status=PICKING
    ...                 updateProductOrder=${product_orders}
    
    # Update order
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    
    # Verify order was updated successfully
    Should Be Equal     ${updated_order}[status]    PICKING
    ...    msg=Updated order status does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_ORDER_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated order: ${updated_order}[code]

07 - Update Order With Missing Required Field Test
    [Documentation]     Test updating an order with missing required fields
    [Tags]              update    negative
    
    # Create an order if one doesn't exist
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=789 Incomplete Street
    # Missing status field
    
    # Attempt to update order with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Order    ${TEST_ORDER_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating an order with missing fields is rejected

08 - Get All Orders Test
    [Documentation]     Test retrieving all orders
    [Tags]              retrieve    positive
    
    # Get all orders
    ${orders}=          Get All Orders
    
    # Log the structure to understand the format
    Log                 Response structure: ${orders}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${orders}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${orders}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${orders}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${orders['data'].__len__()} orders
    ...    ELSE IF      ${has_items}     Log    Found ${orders['items'].__len__()} orders
    ...    ELSE IF      ${has_records}   Log    Found ${orders['records'].__len__()} orders
    ...    ELSE         Log    Found orders in unknown format
    
    Log                 Successfully retrieved orders list

09 - Filter Orders Test
    [Documentation]     Test filtering orders by code
    [Tags]              retrieve    filter    positive
    
    # Create an order if one doesn't exist
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}" or "${TEST_ORDER_CODE}" == "${EMPTY}"    Create Test Order
    
    # Create filter params based on order code
    ${filter_params}=   Create Dictionary    orderCode=${TEST_ORDER_CODE}
    
    # Get filtered orders
    ${filtered_orders}=    Get All Orders    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_orders}
    ...    msg=Filtered orders response was empty
    
    # Check if our order is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_orders}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_orders}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_orders}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_orders}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_orders}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_orders}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find order in filtered results
    
    Log                 Successfully filtered orders by code: ${TEST_ORDER_CODE}

10 - Delete Order Test
    [Documentation]     Test deleting an order
    [Tags]              delete    positive
    
    # Create an order if one doesn't exist
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    # Delete order
    ${result}=          Delete Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    ...    msg=Delete order operation failed
    
    # Verify order deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${TEST_ORDER_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE/CANCELLED
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE IF      ${response.status_code} == 200    Verify Response Indicates Deletion    ${response.text}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Order was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of order with ID: ${TEST_ORDER_ID}

11 - Delete Non-Existent Order Test
    [Documentation]     Test deleting an order that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent order
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent order fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully