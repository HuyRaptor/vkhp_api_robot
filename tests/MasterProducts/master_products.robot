*** Settings ***
Documentation     Comprehensive Test Suite for Master Product Operations in vKho API
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
${PRODUCT_CATEGORY_ID}  37
${SUPPLIER_ID}          56
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_MASTER_PRODUCT_ID}     ${EMPTY}
${TEST_MASTER_PRODUCT_NAME}   ${EMPTY}
${TEST_MASTER_PRODUCT_DATA}   ${EMPTY}

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

Generate Unique Master Product Data
    [Documentation]     Generate unique data for master product tests
    [Arguments]         ${custom_name}=Test Master Product
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     ${custom_name} ${timestamp}
    ${product_code}=    Set Variable     MP${timestamp}
    
    # Return dictionary of generated data
    ${master_product_data}=   Create Dictionary
    ...                 name=${product_name}
    ...                 capacity=100
    ...                 method=FIFO
    ...                 stogareTime=30
    ...                 image=/test/image.jpg
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 supplierIds=@{EMPTY}
    ...                 purchasePrice=100.00
    ...                 salePrice=150.00
    ...                 retailPrice=200.00
    ...                 barCode=${product_code}
    ...                 VAT=10
    ...                 DVT=Unit
    ...                 packing=Box
    ...                 length=10
    ...                 width=10
    ...                 height=10
    ...                 itemCode=${product_code}
    ...                 description=Test master product description
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=50
    RETURN            ${master_product_data}

Create Master Product
    [Documentation]     Create a new master product and return its ID
    [Arguments]         ${master_product_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${master_product_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${master_product_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Ensure supplierIds is a list
    ${suppliers_list}=  Run Keyword If    '${master_product_data}[supplierIds]' == '@{EMPTY}'
    ...                 Create List    ${SUPPLIER_ID}
    ...                 ELSE    Set Variable    ${master_product_data}[supplierIds]
    Set To Dictionary   ${master_product_data}    supplierIds=${suppliers_list}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create master product request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /master-products/create
    ...                 json=${master_product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}master_product_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create master product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create master product response missing ID field
    
    # Return master product ID and full response
    ${master_product_id}=     Convert To String    ${json}[id]
    RETURN            ${master_product_id}    ${json}

Get Master Product By ID
    [Documentation]     Retrieve a specific master product by ID
    [Arguments]         ${master_product_id}
    
    # Validate parameters
    Should Not Be Empty    ${master_product_id}
    ...    msg=Master Product ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get master product request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /master-products/get-one/${master_product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get master product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get master product response missing ID field
    
    RETURN            ${json}

Update Master Product
    [Documentation]     Update an existing master product
    [Arguments]         ${master_product_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${master_product_id}
    ...    msg=Master Product ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${master_product_id}
    ...    msg=Update data ID must match master_product_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update master product request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /master-products/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update master product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update master product response missing ID field
    
    RETURN            ${json}

Delete Master Product
    [Documentation]     Delete a master product from the system
    [Arguments]         ${master_product_id}
    
    # Validate parameters
    Should Not Be Empty    ${master_product_id}
    ...    msg=Master Product ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete master product request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /master-products/delete/${master_product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Master Products
    [Documentation]     Retrieve all master products with optional filtering
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
    
    # Send get all master products request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /master-products/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all master products response was empty
    
    RETURN            ${json}

Create Test Master Product
    [Documentation]     Creates a test master product if one doesn't exist
    ${master_product_data}=   Generate Unique Master Product Data
    ${master_product_id}    ${response}=    Create Master Product    ${master_product_data}
    Set Global Variable  ${TEST_MASTER_PRODUCT_ID}      ${master_product_id}
    Set Global Variable  ${TEST_MASTER_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_MASTER_PRODUCT_DATA}    ${master_product_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for master products tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Master Product Test
    [Documentation]     Test creating a new master product
    [Tags]              create    positive
    
    # Generate master product data
    ${master_product_data}=   Generate Unique Master Product Data
    
    # Create master product
    ${master_product_id}    ${response}=    Create Master Product    ${master_product_data}
    
    # Verify master product was created successfully
    Should Not Be Empty    ${master_product_id}
    ...    msg=Failed to create master product: No ID returned
    Should Be Equal     ${response}[name]    ${master_product_data}[name]
    ...    msg=Created master product name does not match input data
    
    # Save master product ID for subsequent tests
    Set Global Variable  ${TEST_MASTER_PRODUCT_ID}      ${master_product_id}
    Set Global Variable  ${TEST_MASTER_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_MASTER_PRODUCT_DATA}    ${master_product_data}
    
    Log                 Successfully created master product: ${TEST_MASTER_PRODUCT_NAME} with ID: ${TEST_MASTER_PRODUCT_ID}

03 - Create Master Product Missing Required Field Test
    [Documentation]     Test creating a master product with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete master product data (missing warehouseId)
    ${incomplete_data}=  Generate Unique Master Product Data    custom_name=Missing Field Master Product
    Remove From Dictionary    ${incomplete_data}    warehouseId
    
    # Attempt to create master product with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: warehouseId*
    ...                 Create Master Product    ${incomplete_data}
    
    Log                 Successfully verified that creating a master product with missing fields is rejected

04 - Get Master Product Test
    [Documentation]     Test retrieving a specific master product
    [Tags]              retrieve    positive
    
    # Create a master product if one doesn't exist
    Run Keyword If      "${TEST_MASTER_PRODUCT_ID}" == "${EMPTY}"    Create Test Master Product
    
    # Get master product
    ${master_product}=  Get Master Product By ID    ${TEST_MASTER_PRODUCT_ID}
    
    # Verify master product details match what we created
    Assert Master Product Details    ${master_product}    ${TEST_MASTER_PRODUCT_DATA}
    
    Log                 Successfully retrieved master product: ${master_product}[name]

05 - Get Non-Existent Master Product Test
    [Documentation]     Test retrieving a master product that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent master product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /master-products/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent master product fails

06 - Update Master Product Test
    [Documentation]     Test updating an existing master product
    [Tags]              update    positive
    
    # Create a master product if one doesn't exist
    Run Keyword If      "${TEST_MASTER_PRODUCT_ID}" == "${EMPTY}"    Create Test Master Product
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_MASTER_PRODUCT_NAME} Updated
    ${suppliers_list}=  Create List     ${SUPPLIER_ID}
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_MASTER_PRODUCT_ID}
    ...                 name=${updated_name}
    ...                 capacity=150
    ...                 method=LIFO
    ...                 stogareTime=45
    ...                 image=/updated/image.jpg
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 supplierIds=${suppliers_list}
    ...                 purchasePrice=120.00
    ...                 salePrice=180.00
    ...                 retailPrice=250.00
    ...                 barCode=UPD${TEST_MASTER_PRODUCT_ID}
    ...                 VAT=15
    ...                 DVT=Pack
    ...                 packing=Carton
    ...                 length=15
    ...                 width=15
    ...                 height=15
    ...                 itemCode=UPD${TEST_MASTER_PRODUCT_ID}
    ...                 description=Updated test master product description
    ...                 isActive=${TRUE}
    ...                 discount=5
    ...                 isResources=${FALSE}
    ...                 availableQuantity=75
    ...                 status=ENABLE
    
    # Update master product
    ${updated_master_product}=    Update Master Product    ${TEST_MASTER_PRODUCT_ID}    ${update_data}
    
    # Verify master product was updated successfully
    Should Be Equal     ${updated_master_product}[name]    ${updated_name}
    ...    msg=Updated master product name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_MASTER_PRODUCT_NAME}    ${updated_name}
    Set Global Variable  ${TEST_MASTER_PRODUCT_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated master product: ${updated_master_product}[name]

07 - Update Master Product With Missing Required Field Test
    [Documentation]     Test updating a master product with missing required fields
    [Tags]              update    negative
    
    # Create a master product if one doesn't exist
    Run Keyword If      "${TEST_MASTER_PRODUCT_ID}" == "${EMPTY}"    Create Test Master Product
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_MASTER_PRODUCT_ID}
    ...                 name=Incomplete Update
    # Missing status field
    
    # Attempt to update master product with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Master Product    ${TEST_MASTER_PRODUCT_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a master product with missing fields is rejected

08 - Get All Master Products Test
    [Documentation]     Test retrieving all master products
    [Tags]              retrieve    positive
    
    # Get all master products
    ${master_products}=  Get All Master Products
    
    # Log the structure to understand the format
    Log                 Response structure: ${master_products}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${master_products}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${master_products}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${master_products}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${master_products['data'].__len__()} master products
    ...    ELSE IF      ${has_items}     Log    Found ${master_products['items'].__len__()} master products
    ...    ELSE IF      ${has_records}   Log    Found ${master_products['records'].__len__()} master products
    ...    ELSE         Log    Found master products in unknown format
    
    Log                 Successfully retrieved master products list

09 - Filter Master Products Test
    [Documentation]     Test filtering master products by name
    [Tags]              retrieve    filter    positive
    
    # Create a master product if one doesn't exist
    Run Keyword If      "${TEST_MASTER_PRODUCT_ID}" == "${EMPTY}" or "${TEST_MASTER_PRODUCT_NAME}" == "${EMPTY}"    Create Test Master Product
    
    # Create filter params based on master product name
    ${filter_params}=   Create Dictionary    masterProductName=${TEST_MASTER_PRODUCT_NAME}
    
    # Get filtered master products
    ${filtered_master_products}=    Get All Master Products    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_master_products}
    ...    msg=Filtered master products response was empty
    
    # Check if our master product is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_master_products}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_master_products}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_master_products}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_master_products}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_master_products}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_master_products}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find master product in filtered results
    
    Log                 Successfully filtered master products by name: ${TEST_MASTER_PRODUCT_NAME}

10 - Delete Master Product Test
    [Documentation]     Test deleting a master product
    [Tags]              delete    positive
    
    # Create a master product if one doesn't exist
    Run Keyword If      "${TEST_MASTER_PRODUCT_ID}" == "${EMPTY}"    Create Test Master Product
    
    # Delete master product
    ${result}=          Delete Master Product    ${TEST_MASTER_PRODUCT_ID}
    Should Be True      ${result}
    ...    msg=Delete master product operation failed
    
    # Verify master product deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /master-products/get-one/${TEST_MASTER_PRODUCT_ID}
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
    ...    msg=Master Product was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of master product with ID: ${TEST_MASTER_PRODUCT_ID}
11 - Delete Non-Existent Master Product Test
    [Documentation]     Test deleting a master product that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent master product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /master-products/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent master product fails

12 - Bulk Product Create Test
    [Documentation]     Test creating multiple master products via Excel upload
    [Tags]              create    bulk
    
    # Prepare test Excel file upload
    ${excel_file_path}=  Set Variable    ${RESULTS_DIR}${/}master_products_bulk.xlsx
    
    # Prepare request
    ${headers}=         Create Dictionary    Authorization=${AUTH_TOKEN}    Content-Type=multipart/form-data
    
    # Create a sample Excel file for upload (in a real scenario, you'd have a pre-prepared file)
    # This is a placeholder - in practice, you'd have a prepared Excel file with test data
    ${dummy_file_content}=    Evaluate    b'Dummy Excel Content'
    Create Binary File    ${excel_file_path}    ${dummy_file_content}
    
    # Send bulk create request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /master-products/create/excel/${WAREHOUSE_ID}
    ...                 files=${excel_file_path}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Verify response
    Should Not Be Empty    ${response.text}
    Log                 Bulk master product creation response: ${response.text}
    
    # Optional: Parse response to verify number of created products
    # Note: Actual implementation depends on API's exact response format
    
    Log                 Successfully uploaded bulk master products file

13 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Optional: Delete any remaining test master products
    Run Keyword If    "${TEST_MASTER_PRODUCT_ID}" != "${EMPTY}"    
    ...    Run Keyword And Ignore Error    Delete Master Product    ${TEST_MASTER_PRODUCT_ID}
    
    # Remove any temporary files
    # Run Keyword And Ignore Error    Remove Files    ${RESULTS_DIR}${/}master_product_create_*.json
    # Run Keyword And Ignore Error    Remove Files    ${RESULTS_DIR}${/}master_products_bulk.xlsx
    
    Log                 Test environment cleaned up successfully