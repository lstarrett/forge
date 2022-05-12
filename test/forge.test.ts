import { expect as expectCDK, matchTemplate, MatchStyle } from '@aws-cdk/assert';
import * as cdk from '@aws-cdk/core';
import * as Forge from '../lib/forge-stack';

test('Empty Stack', () => {
    const app = new cdk.App();
    // WHEN
    const stack = new Forge.ForgeStack(app, 'MyTestStack');
    // THEN
    expectCDK(stack).to(matchTemplate({
      "Resources": {}
    }, MatchStyle.EXACT))
});
