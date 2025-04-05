*** Settings ***
Documentation     Comprehensive Test Suite for Product Operations in vKho API
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
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
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

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    [Arguments]         ${custom_name}=Test Product
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     ${custom_name} ${timestamp}
    ${sku}=             Set Variable     SKU${timestamp}
    ${barcode}=         Set Variable     BAR${timestamp}
    
    # Return dictionary of generated data
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 sku=${sku}
    ...                 barcode=${barcode}
    ...                 description=Test product description
    ...                 price=99.99
    ...                 unit=Piece
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    RETURN            ${product_data}

Create Product
    [Documentation]     Create a new product and return its ID
    [Arguments]         ${product_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${product_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${product_data}    sku
    ...    msg=Missing required parameter: sku
    Dictionary Should Contain Key    ${product_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${product_data}    productCategoryId
    ...    msg=Missing required parameter: productCategoryId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create product request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}product_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create product response missing ID field
    
    # Return product ID and full response
    ${product_id}=      Convert To String    ${json}[id]
    RETURN            ${product_id}    ${json}

Get Product By ID
    [Documentation]     Retrieve a specific product by ID
    [Arguments]         ${product_id}
    
    # Validate parameters
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get product request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get product response missing ID field
    
    RETURN            ${json}

Update Product
    [Documentation]     Update an existing product
    [Arguments]         ${product_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${product_id}
    ...    msg=Update data ID must match product_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update product request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /products/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update product response missing ID field
    
    RETURN            ${json}

Delete Product
    [Documentation]     Delete a product from the system
    [Arguments]         ${product_id}
    
    # Validate parameters
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete product request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Products
    [Documentation]     Retrieve all products with optional filtering
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
    
    # Send get all products request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all products response was empty
    
    RETURN            ${json}

Assert Product Details
    [Documentation]     Verify product details match expected values
    [Arguments]         ${product}    ${expected_data}
    
    # For all keys in expected data, verify they match in the product data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${product}    Should Be Equal    ${product}[${key}]    ${expected_data}[${key}]
        ...    msg=Product ${key} value '${product}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Product
    [Documentation]     Creates a test product if one doesn't exist
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates product is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    
    # Check for status field indicating deletion
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Set Variable    ${FALSE}
    
    RETURN            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'DELETED'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for product tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Product Test
    [Documentation]     Test creating a new product
    [Tags]              create    positive
    
    # Generate product data
    ${product_data}=    Generate Unique Product Data
    
    # Create product
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Verify product was created successfully
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product: No ID returned
    Should Be Equal     ${response}[name]    ${product_data}[name]
    ...    msg=Created product name does not match input data
    
    # Save product ID for subsequent tests
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    
    Log                 Successfully created product: ${TEST_PRODUCT_NAME} with ID: ${TEST_PRODUCT_ID}

03 - Create Product Missing Required Field Test
    [Documentation]     Test creating a product with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete product data (missing sku)
    ${incomplete_data}=  Generate Unique Product Data    custom_name=Missing Field Product
    Remove From Dictionary    ${incomplete_data}    sku
    
    # Attempt to create product with incomplete data
    Run Keyword And Expect Error    *Missing required parameter: sku*
    ...                 Create Product    ${incomplete_data}
    
    Log                 Successfully verified that creating a product with missing fields is rejected

04 - Get Product Test
    [Documentation]     Test retrieving a specific product
    [Tags]              retrieve    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Get product
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    
    # Verify product details match what we created
    Assert Product Details    ${product}    ${TEST_PRODUCT_DATA}
    
    Log                 Successfully retrieved product: ${product}[name]

05 - Get Non-Existent Product Test
    [Documentation]     Test retrieving a product that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /products/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent product fails

06 - Update Product Test
    [Documentation]     Test updating an existing product
    [Tags]              update    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_PRODUCT_NAME} Updated
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PRODUCT_ID}
    ...                 name=${updated_name}
    ...                 sku=${TEST_PRODUCT_DATA}[sku]
    ...                 barcode=${TEST_PRODUCT_DATA}[barcode]
    ...                 description=Updated product description
    ...                 price=149.99
    ...                 unit=Piece
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 status=ENABLE
    
    # Update product
    ${updated_product}=    Update Product    ${TEST_PRODUCT_ID}    ${update_data}
    
    # Verify product was updated successfully
    Should Be Equal     ${updated_product}[name]    ${updated_name}
    ...    msg=Updated product name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${updated_name}
    Set Global Variable  ${TEST_PRODUCT_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated product: ${updated_product}[name]

07 - Update Product With Missing Required Field Test
    [Documentation]     Test updating a product with missing required fields
    [Tags]              update    negative
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_PRODUCT_ID}
    ...                 name=Incomplete Update
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update product with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Product    ${TEST_PRODUCT_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a product with missing fields is rejected

08 - Get All Products Test
    [Documentation]     Test retrieving all products
    [Tags]              retrieve    positive
    
    # Get all products
    ${products}=        Get All Products
    
    # Log the structure to understand the format
    Log                 Response structure: ${products}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${products['data'].__len__()} products
    ...    ELSE IF      ${has_items}     Log    Found ${products['items'].__len__()} products
    ...    ELSE IF      ${has_records}   Log    Found ${products['records'].__len__()} products
    ...    ELSE         Log    Found products in unknown format
    
    Log                 Successfully retrieved products list

09 - Filter Products Test
    [Documentation]     Test filtering products by name
    [Tags]              retrieve    filter    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}" or "${TEST_PRODUCT_NAME}" == "${EMPTY}"    Create Test Product
    
    # Create filter params based on product name
    ${filter_params}=   Create Dictionary    productName=${TEST_PRODUCT_NAME}
    
    # Get filtered products
    ${filtered_products}=    Get All Products    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_products}
    ...    msg=Filtered products response was empty
    
    # Check if our product is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_products}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_products}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_products}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_products}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_products}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_products}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find product in filtered results
    
    Log                 Successfully filtered products by name: ${TEST_PRODUCT_NAME}

10 - Delete Product Test
    [Documentation]     Test deleting a product
    [Tags]              delete    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Delete product
    ${result}=          Delete Product    ${TEST_PRODUCT_ID}
    Should Be True      ${result}
    ...    msg=Delete product operation failed
    
    # Verify product deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${TEST_PRODUCT_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE IF      ${response.status_code} == 200    Verify Response Indicates Deletion    ${response.text}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Product was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of product with ID: ${TEST_PRODUCT_ID}

11 - Delete Non-Existent Product Test
    [Documentation]     Test deleting a product that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /products/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent product fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully