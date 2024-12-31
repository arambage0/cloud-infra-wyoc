import boto3
import logging
from argparse import ArgumentParser
from botocore.exceptions import ClientError

# logger config
logger = logging.getLogger()
logging.basicConfig(level=logging.INFO,format='%(message)s')

# arg oparser config
parser = ArgumentParser()
parser.add_argument("-v", "--vpc", required=True, help="Enter vpc id to detail")
parser.add_argument("-r", "--region", default="eu-west-1", help="AWS region that the VPC provisioned in")
args = parser.parse_args()

app_region: str = args.region
vpc_id: str = args.vpc
eni_entries  = []


ec2_resource = boto3.resource('ec2', region_name=app_region)
ec2_client = boto3.client('ec2', region_name=app_region)


def extract_eni_details():
    enis = ec2_client.describe_network_interfaces(Filters=[{'Name': 'vpc-id','Values': [vpc_id, ]}, ])
    for eni in enis['NetworkInterfaces']:
        eni_entry = '|InterfaceType:{}|EniId:{}|Description:{}|'.format(eni['InterfaceType'],eni['NetworkInterfaceId'],eni['Description'])
        eni_entries.append(eni_entry)

    eni_entries.sort()
    for eni_item in eni_entries:
        print(eni_item)
        logger.info("{}".format(eni_item))


def is_vpc_exists():
    vpc_exists = False
    try:
        vpcs = list(ec2_resource.vpcs.filter(Filters=[]))
    except ClientError as e:
        logger.warning(e.response['Error']['Message'])
        exit()
    logger.info("VPCs in region {}:".format(app_region))
    for vpc in vpcs:
        logger.info(vpc.id)
        if vpc.id == vpc_id:
            vpc_exists = True

    logger.info("--------------------------------------------")
    return vpc_exists



if __name__ == '__main__':

    if is_vpc_exists():
        extract_eni_details()
    else:
        logger.warning("The given VPC ID was not found in {}".format(app_region))
