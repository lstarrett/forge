#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { ForgeStack } from '../lib/forge-stack';

const app = new cdk.App();

new ForgeStack(app, 'Forge')

app.synth();
