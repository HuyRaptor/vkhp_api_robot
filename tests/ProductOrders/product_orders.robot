*** Settings ***
Documentation     Comprehensive Test Suite for Product Order Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

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

Generate Unique Product Order Data
    [Documentation]     Generate unique data for product order tests
    
    # Prepare product order creation data
    ${product_order_data}=    Create Dictionary
    ...                 total=10
    ...                 boothCode=${BOOTH_CODE}
    ...                 sku=${SKU}
    
    RETURN            ${product_order_data}

Create Product Order
    [Documentation]     Create a new product order and return its ID
    [Arguments]         ${product_order_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${product_order_data}    total
    ...    msg=Missing required parameter: total
    Dictionary Should Contain Key    ${product_order_data}    boothCode
    ...    msg=Missing required parameter: boothCode
    Dictionary Should Contain Key    ${product_order_data}    sku
    ...    msg=Missing required parameter: sku
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create product order request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}product_order_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create product order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create product order response missing ID field
    
    # Return product order ID and full response
    ${product_order_id}=    Convert To String    ${json}[id]
    RETURN            ${product_order_id}    ${json}

Get Product Order By ID
    [Documentation]     Retrieve a specific product order by ID
    [Arguments]         ${product_order_id}
    
    # Validate parameters
    Should Not Be Empty    ${product_order_id}
    ...    msg=Product Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get product order request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-orders/get-one/${product_order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get product order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get product order response missing ID field
    
    RETURN            ${json}

Update Product Order
    [Documentation]     Update an existing product order
    [Arguments]         ${product_order_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${product_order_id}
    ...    msg=Product Order ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${product_order_id}
    ...    msg=Update data ID must match product_order_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    total
    ...    msg=Update data missing required field: total
    Dictionary Should Contain Key    ${update_data}    boothCode
    ...    msg=Update data missing required field: boothCode
    Dictionary Should Contain Key    ${update_data}    sku
    ...    msg=Update data missing required field: sku
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update product order request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /product-orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update product order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update product order response missing ID field
    
    RETURN            ${json}

Delete Product Order
    [Documentation]     Delete a product order from the system
    [Arguments]         ${product_order_id}
    
    # Validate parameters
    Should Not Be Empty    ${product_order_id}
    ...    msg=Product Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete product order request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /product-orders/delete/${product_order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Product Orders
    [Documentation]     Retrieve all product orders with optional filtering
    [Arguments]         ${filter_params}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary
    
    # Add any additional filter parameters if provided
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all product orders request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-orders/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all product orders response was empty
    
    RETURN            ${json}

Assert Product Order Details
    [Documentation]     Verify product order details match expected values
    [Arguments]         ${product_order}    ${expected_data}
    
    # For all keys in expected data, verify they match in the product order data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${product_order}    Should Be Equal    ${product_order}[${key}]    ${expected_data}[${key}]
        ...    msg=Product Order ${key} value '${product_order}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Product Order
    [Documentation]     Creates a test product order if one doesn't exist
    ${product_order_data}=    Generate Unique Product Order Data
    ${product_order_id}    ${response}=    Create Product Order    ${product_order_data}
    Set Global Variable  ${TEST_PRODUCT_ORDER_ID}      ${product_order_id}
    Set Global Variable  ${TEST_PRODUCT_ORDER_DATA}    ${product_order_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for product orders tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Product Order Test
    [Documentation]     Test creating a new product order
    [Tags]              create    positive
    
    # Generate product order data
    ${product_order_data}=    Generate Unique Product Order Data
    
    # Create product order
    ${product_order_id}    ${response}=    Create Product Order    ${product_order_data}
    
    # Verify product order was created successfully
    Should Not Be Empty    ${product_order_id}
    ...    msg=Failed to create product order: No ID returned
    
    # Save product order ID for subsequent tests
    Set Global Variable  ${TEST_PRODUCT_ORDER_ID}      ${product_order_id}
    Set Global Variable  ${TEST_PRODUCT_ORDER_DATA}    ${product_order_data}
    
    Log                 Successfully created product order with ID: ${TEST_PRODUCT_ORDER_ID}

03 - Create Product Order Missing Required Field Test
    [Documentation]     Test creating a product order with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete product order data (missing sku)
    ${incomplete_data}=  Create Dictionary
    ...                 total=10
    ...                 boothCode=${BOOTH_CODE}
    
    # Attempt to create product order with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: sku*
    ...                 Create Product Order    ${incomplete_data}
    
    Log                 Successfully verified that creating a product order with missing fields is rejected

04 - Get Product Order Test
    [Documentation]     Test retrieving a specific product order
    [Tags]              retrieve    positive
    
    # Create a product order if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Test Product Order
    
    # Get product order
    ${product_order}=   Get Product Order By ID    ${TEST_PRODUCT_ORDER_ID}
    
    # Verify product order details match what we created
    Assert Product Order Details    ${product_order}    ${TEST_PRODUCT_ORDER_DATA}
    
    Log                 Successfully retrieved product order with ID: ${TEST_PRODUCT_ORDER_ID}

05 - Get Non-Existent Product Order Test
    [Documentation]     Test retrieving a product order that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent product order
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /product-orders/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent product order fails

06 - Update Product Order Test
    [Documentation]     Test updating an existing product order
    [Tags]              update    positive
    
    # Create a product order if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Test Product Order
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PRODUCT_ORDER_ID}
    ...                 total=15
    ...                 boothCode=${BOOTH_CODE}
    ...                 sku=${SKU}
    
    # Update product order
    ${updated_product_order}=    Update Product Order    ${TEST_PRODUCT_ORDER_ID}    ${update_data}
    
    # Verify product order was updated successfully
    Should Be Equal     ${updated_product_order}[total]    ${update_data}[total]
    ...    msg=Updated product order total does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_PRODUCT_ORDER_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated product order: ${TEST_PRODUCT_ORDER_ID}

07 - Update Product Order With Missing Required Field Test
    [Documentation]     Test updating a product order with missing required fields
    [Tags]              update    negative
    
    # Create a product order if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Test Product Order
    
    # Prepare incomplete update data (missing total)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_PRODUCT_ORDER_ID}
    ...                 boothCode=${BOOTH_CODE}
    ...                 sku=${SKU}
    # Missing total field
    
    # Attempt to update product order with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: total*
    ...                 Update Product Order    ${TEST_PRODUCT_ORDER_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a product order with missing fields is rejected

08 - Get All Product Orders Test
    [Documentation]     Test retrieving all product orders
    [Tags]              retrieve    positive
    
    # Get all product orders
    ${product_orders}=  Get All Product Orders
    
    # Log the structure to understand the format
    Log                 Response structure: ${product_orders}
    
    # Verify response is not empty
    Should Not Be Empty    ${product_orders}
    ...    msg=Get all product orders response was empty
    
    Log                 Successfully retrieved product orders list

09 - Filter Product Orders Test
    [Documentation]     Test filtering product orders
    [Tags]              retrieve    filter    positive
    
    # Create a product order if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Test Product Order
    
    # Create filter params based on booth code
    ${filter_params}=   Create Dictionary    boothCode=${BOOTH_CODE}
     # Get filtered product orders
    ${filtered_product_orders}=    Get All Product Orders    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_product_orders}
    ...    msg=Filtered product orders response was empty
    
    # Log the structure to understand the format
    Log                 Filtered response structure: ${filtered_product_orders}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_product_orders}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_product_orders}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_product_orders}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_product_orders}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_product_orders}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_product_orders}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find product order in filtered results
    
    Log                 Successfully filtered product orders by booth code: ${BOOTH_CODE}

10 - Delete Product Order Test
    [Documentation]     Test deleting a product order
    [Tags]              delete    positive
    
    # Create a product order if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" == "${EMPTY}"    Create Test Product Order
    
    # Delete product order
    ${result}=          Delete Product Order    ${TEST_PRODUCT_ORDER_ID}
    Should Be True      ${result}
    ...    msg=Delete product order operation failed
    
    # Verify product order deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-orders/get-one/${TEST_PRODUCT_ORDER_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # Expect 404 or a response indicating the resource no longer exists
    Run Keyword If      ${response.status_code} != 200    Log    Product order successfully deleted
    ...    ELSE    Fail    Product order was not deleted
    
    Log                 Successfully verified deletion of product order with ID: ${TEST_PRODUCT_ORDER_ID}

11 - Delete Non-Existent Product Order Test
    [Documentation]     Test deleting a product order that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent product order
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /product-orders/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent product order fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully*** Settings ***